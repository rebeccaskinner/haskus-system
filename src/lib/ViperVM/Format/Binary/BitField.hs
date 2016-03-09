{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE AllowAmbiguousTypes #-}

-- | Bit fields (as in C)
--
-- This module allows you to define bit fields over words. For instance, you can
-- have a Word16 split into 3 fields X, Y and Z composed of 5, 9 and 2 bits
-- respectively.
--
--                   X             Y          Z
--  w :: Word16 |0 0 0 0 0|0 0 0 0 0 0 0 0 0|0 0|
-- 
-- You define it as follows:
-- @
-- {-# LANGUAGE DataKinds #-}
--
-- w :: BitFields Word16 '[ BitField 5 "X" Word8 
--                        , BitField 9 "Y" Word16
--                        , BitField 2 "Z" Word8
--                        ]
-- w = BitFields 0x0102
-- @
--
-- Note that each field has its own associated type (e.g. Word8 for X and Z)
-- that must be large enough to hold the number of bits for the field.
--
-- Operations on BitFields expect that the cumulated size of the fields is equal
-- to the whole word size: use a padding field if necessary.
-- 
-- You can extract and update the value of a field by its name:
--
-- @
-- x = extractField (Proxy :: Proxy "X") w
-- z = extractField (Proxy :: Proxy "Z") w
-- w' = updateField (Proxy :: Proxy "Y") 0x16 w
-- @
--
-- Fields can also be 'BitSet' or 'EnumField':
-- @
-- {-# LANGUAGE DataKinds #-}
--
-- data A = A0 | A1 | A2 | A3 deriving (Enum,CEnum)
--
-- data B = B0 | B1 deriving (Enum,CBitSet)
--
-- w :: BitFields Word16 '[ BitField 5 "X" (EnumField Word8 A)
--                        , BitField 9 "Y" Word16
--                        , BitField 2 "Z" (BitSet Word8 B)
--                        ]
-- w = BitFields 0x0102
-- @
module ViperVM.Format.Binary.BitField
   ( BitFields (..)
   , BitField (..)
   , extractField
   , updateField
   , withField
   , matchFields
   )
where

import Data.HList.FakePrelude (ApplyAB(..))
import Data.HList.HList
import Data.Word
import Data.Int
import Data.Bits
import GHC.TypeLits
import Data.Proxy
import Numeric
import Foreign.Storable
import Foreign.CStorable
import ViperVM.Format.Binary.BitSet as BitSet
import ViperVM.Format.Binary.Enum
import ViperVM.Utils.HList (HFoldr'(..))

-- | Bit fields on a base type b
newtype BitFields b (f :: [*]) = BitFields b deriving (Storable)

instance Storable b => CStorable (BitFields b fields) where
   cPeek      = peek
   cPoke      = poke
   cAlignment = alignment
   cSizeOf    = sizeOf

instance (Integral b, Show b) => Show (BitFields b fields) where
   show (BitFields w) = "0x" ++ showHex w ""

-- | A field of n bits
newtype BitField (n :: Nat) (name :: Symbol) s = BitField s deriving (Storable)

instance Storable s => CStorable (BitField n name s) where
   cPeek      = peek
   cPoke      = poke
   cAlignment = alignment
   cSizeOf    = sizeOf

type family BitSize a :: Nat
type instance BitSize Word8  = 8
type instance BitSize Word16 = 16
type instance BitSize Word32 = 32
type instance BitSize Word64 = 64

-- | Get the bit offset of a field from its name
type family Offset (name :: Symbol) fs :: Nat where
   Offset name (BitField n name  s ': xs) = AddOffset xs
   Offset name (BitField n name2 s ': xs) = Offset name xs

type family AddOffset fs :: Nat where
   AddOffset '[]                        = 0
   AddOffset '[BitField n name s]       = n
   AddOffset (BitField n name s ': xs)  = n + AddOffset xs

-- | Get the type of a field from its name
type family Output (name :: Symbol) fs :: * where
   Output name (BitField n name  s ': xs) = s
   Output name (BitField n name2 s ': xs) = Output name xs

-- | Get the size of a field from it name
type family Size (name :: Symbol) fs :: Nat where
   Size name (BitField n name  s ': xs) = n
   Size name (BitField n name2 s ': xs) = Size name xs

-- | Get the whole size of a BitFields
type family WholeSize fs :: Nat where
   WholeSize '[]                        = 0
   WholeSize (BitField n name s ': xs)  = n + WholeSize xs


class Field f where
   fromField :: Integral b => f -> b
   toField   :: Integral b => b -> f

instance Field Bool where
   fromField True  = 1
   fromField False = 0
   toField 0  = False
   toField _  = True

instance Field Word where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Word8 where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Word16 where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Word32 where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Word64 where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Int where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Int8 where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Int16 where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Int32 where
   fromField = fromIntegral
   toField   = fromIntegral

instance Field Int64 where
   fromField = fromIntegral
   toField   = fromIntegral

instance (FiniteBits b, Integral b, CBitSet a) => Field (BitSet b a) where
   fromField = fromIntegral . BitSet.toBits
   toField   = BitSet.fromBits . fromIntegral

instance CEnum a => Field (EnumField b a) where
   fromField = fromCEnum . fromEnumField
   toField   = toEnumField . toCEnum

-- | Get the value of a field
extractField :: forall name fields b .
   ( KnownNat (Offset name fields)
   , KnownNat (Size name fields)
   , WholeSize fields ~ BitSize b
   , Bits b, Integral b
   , Field (Output name fields)
   ) => Proxy name -> BitFields b fields -> Output name fields
extractField _ (BitFields w) = toField ((w `shiftR` fromIntegral off) .&. ((1 `shiftL` fromIntegral sz) - 1))
   where
      off = natVal (Proxy :: Proxy (Offset name fields))
      sz  = natVal (Proxy :: Proxy (Size name fields))

{-# INLINE extractField #-}

-- | Set the value of a field
updateField :: forall name fields b .
   ( KnownNat (Offset name fields)
   , KnownNat (Size name fields)
   , WholeSize fields ~ BitSize b
   , Bits b, Integral b
   , Field (Output name fields)
   ) => Proxy name -> Output name fields -> BitFields b fields -> BitFields b fields
updateField _ value (BitFields w) = BitFields $ ((fromField value `shiftL` off) .&. mask) .|. (w .&. complement mask)
   where
      off  = fromIntegral $ natVal (Proxy :: Proxy (Offset name fields))
      sz   = natVal (Proxy :: Proxy (Size name fields))
      mask = ((1 `shiftL` fromIntegral sz) - 1) `shiftL` off

{-# INLINE updateField #-}

-- | Modify the value of a field
withField :: forall name fields b f .
   ( KnownNat (Offset name fields)
   , KnownNat (Size name fields)
   , WholeSize fields ~ BitSize b
   , Bits b, Integral b
   , f ~ Output name fields
   , Field f
   ) => Proxy name -> (f -> f) -> BitFields b fields -> BitFields b fields
withField name f bs = updateField name (f v) bs
   where
      v = extractField name bs

{-# INLINE withField #-}

-------------------------------------------------------------------------------------
-- We use HFoldr' to extract each component and create a HList from it. Then we
-- convert it into a Tuple
-------------------------------------------------------------------------------------
data Extract = Extract

instance forall name bs b l l2 i (n :: Nat) s r w .
   ( bs ~ BitFields w l     -- the bitfields
   , b ~ BitField n name s  -- the current field
   , i ~ (bs, HList l2)     -- input type
   , r ~ (bs, HList (Output name l ': l2))     -- result typ
   , BitSize w ~ WholeSize l
   , Integral w, Bits w
   , KnownNat (Offset name l)
   , KnownNat (Size name l)
   , Field (Output name l)
   ) => ApplyAB Extract (b, i) r where
      applyAB _ (_, (bs,xs)) =
         (bs, HCons (extractField (Proxy :: Proxy name) bs) xs)


matchFields' :: forall l l2 w bs .
   ( bs ~ BitFields w l
   , HFoldr' Extract (bs, HList '[]) l (bs, HList l2)
   ) => bs -> HList l2
matchFields' bs = snd res
   where
      res :: (bs, HList l2)
      res = hFoldr' Extract ((bs, HNil) :: (bs, HList '[])) (undefined :: HList l)

matchFields :: forall l l2 w bs t .
   ( bs ~ BitFields w l
   , HFoldr' Extract (bs, HList '[]) l (bs, HList l2)
   , HTuple l2 t
   ) => bs -> t
matchFields = hToTuple . matchFields'
