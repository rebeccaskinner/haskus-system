{-# LANGUAGE RecordWildCards
           , DeriveGeneric
           , GeneralizedNewtypeDeriving #-}

-- We need this one to use type literal numbers (S (S .. Z)) of size 32
{-# OPTIONS -fcontext-stack=50 #-}

-- | Low level bindings
module ViperVM.Arch.Linux.Graphics.LowLevel
   ( PowerMode(..)
   , ScalingMode(..)
   , DitheringMode(..)
   , DirtyMode(..)
   , ModeFieldPresent(..)
   , SetPlaneStruct(..)
   , GetPlaneStruct(..)
   , GetPlaneResStruct(..)
   , PropertyType(..)
   , toPropType
   , fromPropType
   , PropEnumStruct(..)
   , GetPropStruct(..)
   , SetPropStruct(..)
   , ObjectType(..)
   , toObjectType
   , fromObjectType
   , GetObjPropStruct(..)
   , SetObjPropStruct(..)
   , GetBlobStruct(..)
   , FbCmdStruct(..)
   , FrameBufferMode(..)
   , FbCmd2Struct(..)
   , FrameBufferDirty(..)
   , FbDirtyStruct(..)
   , ModeCmdStruct(..)
   , CursorMode(..)
   , CursorStruct(..)
   , Cursor2Struct(..)
   , ControllerLutStruct(..)
   , ModePageFlip(..)
   , PageFlipStruct(..)
   , CreateGenericStruct(..)
   , MapGenericStruct(..)
   , DestroyGenericStruct(..)
   )
where

import ViperVM.Utils.EnumSet

import Data.Word
import Data.Int
import Foreign.Storable
import Foreign.CStorable
import Foreign.C.Types (CChar)
import Data.Vector.Fixed.Cont (S,Z)
import Data.Vector.Fixed.Storable (Vec)
import GHC.Generics (Generic)
import Data.Bits

import ViperVM.Arch.Linux.Graphics.LowLevel.Mode

type N32 = -- 32 
   S (S (S (S (S (S (S (S (S (S (S (S (S (S (S (S (
   S (S (S (S (S (S (S (S (S (S (S (S (S (S (S (S Z
   )))))))))))))))))))))))))))))))

type Vec4 = Vec (S (S (S (S Z))))


--------------------------------------------
-- From drm/drm_mode.h
--------------------------------------------

type ConnectorNameLength = N32
type PropertyNameLength  = N32

-- | DPMS flags
data PowerMode 
   = PowerOn
   | PowerStandBy
   | PowerSuspend
   | PowerOff
   deriving (Show, Enum)

-- | Scaling mode
data ScalingMode
   = ScaleNone         -- ^ Unmodified timing (display or software can still scale)
   | ScaleFullScreen   -- ^ Full screen, ignore aspect
   | ScaleCenter       -- ^ Centered, no scaling
   | ScaleAspect       -- ^ Full screen, preserve aspect
   deriving (Show,Enum)

-- | Dithering mode
data DitheringMode
   = DitheringOff
   | DitheringOn
   | DitheringAuto
   deriving (Show,Enum)

-- | Dirty mode
data DirtyMode
   = DirtyOff
   | DirtyOn
   | DirtyAnnotate
   deriving (Show,Enum)


data ModeFieldPresent
   = PresentTopField
   | PresentBottomField
   deriving (Show,Enum)

instance EnumBitSet ModeFieldPresent

-- | Data matching the C structure drm_mode_set_plane
data SetPlaneStruct = SetPlaneStruct
   { spPlaneId       :: Word32
   , spCrtcId        :: Word32
   , spFbId          :: Word32
   , spFlags         :: Word32
   , spCrtcX         :: Int32
   , spCrtcY         :: Int32
   , spCrtcW         :: Word32
   , spCrtcH         :: Word32
   , spSrcX          :: Word32
   , spSrcY          :: Word32
   , spSrcH          :: Word32
   , spSrcW          :: Word32
   } deriving Generic

instance CStorable SetPlaneStruct
instance Storable SetPlaneStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   poke        = cPoke
   peek        = cPeek

-- | Data matching the C structure drm_mode_get_plane
data GetPlaneStruct = GetPlaneStruct
   { gpPlaneId       :: Word32
   , gpCrtcId        :: Word32
   , gpFbId          :: Word32
   , gpPossibleCrtcs :: Word32
   , gpGammaSize     :: Word32
   , gpCountFmtTypes :: Word32
   , gpFormatTypePtr :: Word64
   } deriving Generic

instance CStorable GetPlaneStruct
instance Storable GetPlaneStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   poke        = cPoke
   peek        = cPeek

-- | Data matching the C structure drm_mode_get_plane_res
data GetPlaneResStruct = GetPlaneResStruct
   { gprsPlaneIdPtr  :: Word64
   , gprsCountPlanes :: Word32
   } deriving Generic

instance CStorable GetPlaneResStruct
instance Storable GetPlaneResStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   poke        = cPoke
   peek        = cPeek

-- | Type of the property
data PropertyType
   = PropTypePending
   | PropTypeRange
   | PropTypeImmutable
   | PropTypeEnum       -- ^ Enumerated type with text strings
   | PropTypeBlob
   | PropTypeBitmask    -- ^ Bitmask of enumerated types
   | PropTypeObject
   | PropTypeSignedRange
   deriving (Eq,Ord,Show)

toPropType :: Word32 -> PropertyType
toPropType typ =
   case typ of
      -- legacy types: 1 bit per type...
      1  -> PropTypePending
      2  -> PropTypeRange
      4  -> PropTypeImmutable
      8  -> PropTypeEnum
      16 -> PropTypeBlob
      32 -> PropTypeBitmask
      -- newer types, shifted int
      n -> case (n `shiftR` 6) of
         1 -> PropTypeObject
         2 -> PropTypeSignedRange
         _ -> error "Unknown type"

fromPropType :: PropertyType -> Word32
fromPropType typ =
   case typ of
      -- legacy types: 1 bit per type...
      PropTypePending      -> 1
      PropTypeRange        -> 2
      PropTypeImmutable    -> 4
      PropTypeEnum         -> 8
      PropTypeBlob         -> 16
      PropTypeBitmask      -> 32
      -- newer types, shifted int
      PropTypeObject       -> 1 `shiftL` 6
      PropTypeSignedRange  -> 2 `shiftL` 6

-- | Data matching the C structure drm_mode_property_enum
data PropEnumStruct = PropEnumStruct
   { peValue       :: Word64
   , peName        :: StorableWrap (Vec PropertyNameLength CChar)
   } deriving Generic

instance CStorable PropEnumStruct
instance Storable PropEnumStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_get_property
data GetPropStruct = GetPropStruct
   { gpsValuesPtr    :: Word64
   , gpsEnumBlobPtr  :: Word64
   , gpsPropId       :: Word32
   , gpsFlags        :: Word32
   , gpsName         :: StorableWrap (Vec PropertyNameLength CChar)
   , gpsCountValues  :: Word32
   , gpsCountEnumBlobs :: Word32
   } deriving Generic

instance CStorable GetPropStruct
instance Storable GetPropStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_set_property
data SetPropStruct = SetPropStruct
   { spsValue        :: Word64
   , spsPropId       :: Word32
   , spsConnId       :: Word32
   } deriving Generic

instance CStorable SetPropStruct
instance Storable SetPropStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke


data ObjectType
   = ObjectController
   | ObjectConnector
   | ObjectEncoder
   | ObjectMode
   | ObjectProperty
   | ObjectFrameBuffer
   | ObjectBlob
   | ObjectPlane
   deriving (Show,Eq)

toObjectType :: Word32 -> ObjectType
toObjectType x = case x of
   0xcccccccc -> ObjectController
   0xc0c0c0c0 -> ObjectConnector
   0xe0e0e0e0 -> ObjectEncoder
   0xdededede -> ObjectMode
   0xb0b0b0b0 -> ObjectProperty
   0xfbfbfbfb -> ObjectFrameBuffer
   0xbbbbbbbb -> ObjectBlob
   0xeeeeeeee -> ObjectPlane
   _          -> error "Invalid object type"

fromObjectType :: ObjectType -> Word32
fromObjectType x = case x of
   ObjectController   -> 0xcccccccc 
   ObjectConnector    -> 0xc0c0c0c0 
   ObjectEncoder      -> 0xe0e0e0e0 
   ObjectMode         -> 0xdededede 
   ObjectProperty     -> 0xb0b0b0b0 
   ObjectFrameBuffer  -> 0xfbfbfbfb 
   ObjectBlob         -> 0xbbbbbbbb 
   ObjectPlane        -> 0xeeeeeeee 

-- | Data matching the C structure drm_mode_obj_get_properties
data GetObjPropStruct = GetObjPropStruct
   { gopPropsPtr        :: Word64
   , gopValuesPtr       :: Word64
   , gopCountProps      :: Word32
   , gopObjId           :: Word32
   , gopObjType         :: Word32
   } deriving Generic

instance CStorable GetObjPropStruct
instance Storable GetObjPropStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_obj_set_properties
data SetObjPropStruct = SetObjPropStruct
   { sopValue           :: Word64
   , sopPropId          :: Word32
   , sopObjId           :: Word32
   , sopObjType         :: Word32
   } deriving Generic

instance CStorable SetObjPropStruct
instance Storable SetObjPropStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_get_blob
data GetBlobStruct = GetBlobStruct
   { gbBlobId     :: Word32
   , gbLength     :: Word32
   , gbData       :: Word64
   } deriving Generic

instance CStorable GetBlobStruct
instance Storable GetBlobStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_fb_cmd
data FbCmdStruct = FbCmdStruct
   { fcFbId          :: Word32
   , fcWidth         :: Word32
   , fcHeight        :: Word32
   , fcPitch         :: Word32
   , fcBPP           :: Word32
   , fcDepth         :: Word32
   , fcHandle        :: Word32
   } deriving Generic

instance CStorable FbCmdStruct
instance Storable FbCmdStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke


data FrameBufferMode
   = FrameBufferInterlaced
   deriving (Show,Eq,Enum)

instance EnumBitSet FrameBufferMode


-- | Data matching the C structure drm_mode_fb_cmd2
data FbCmd2Struct = FbCmd2Struct
   { fc2FbId          :: Word32
   , fc2Width         :: Word32
   , fc2Height        :: Word32
   , fc2PixelFormat   :: Word32
   , fc2Flags         :: Word32
   , fc2Handles       :: StorableWrap (Vec4 Word32)
   , fc2Pitches       :: StorableWrap (Vec4 Word32)
   , fc2Offsets       :: StorableWrap (Vec4 Word32)
   } deriving Generic

instance CStorable FbCmd2Struct
instance Storable FbCmd2Struct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke


data FrameBufferDirty
   = FrameBufferDirtyNone
   | FrameBufferDirtyAnnotateCopy
   | FrameBufferDirtyAnnotateFill
   | FrameBufferDirtyFlags
   deriving (Show,Eq,Enum)

-- | Data matching the C structure drm_mode_fb_dirty_cmd
data FbDirtyStruct = FbDirtyStruct
   { fdFbId          :: Word32
   , fdFlags         :: Word32
   , fdColor         :: Word32
   , fdNumClips      :: Word32
   , fdClipsPtr      :: Word64
   } deriving Generic

instance CStorable FbDirtyStruct
instance Storable FbDirtyStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_mode_cmd
data ModeCmdStruct = ModeCmdStruct
   { mcConnId     :: Word32
   , mcMode       :: ModeStruct
   } deriving Generic

instance CStorable ModeCmdStruct
instance Storable  ModeCmdStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke


data CursorMode
   = CursorModeBO
   | CursorModeMove
   deriving (Eq,Enum,Show)

instance EnumBitSet CursorMode

-- | Data matching the C structure drm_mode_cursor
data CursorStruct = CursorStruct
   { curFlags     :: Word32
   , curCrtcId    :: Word32
   , curX         :: Int32
   , curY         :: Int32
   , curWidth     :: Word32
   , curHeight    :: Word32
   , curHandle    :: Word32   -- ^ if 0, turns the cursor off
   } deriving Generic

instance CStorable CursorStruct
instance Storable  CursorStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_cursor2
data Cursor2Struct = Cursor2Struct
   { cur2Flags     :: Word32
   , cur2CrtcId    :: Word32
   , cur2X         :: Int32
   , cur2Y         :: Int32
   , cur2Width     :: Word32
   , cur2Height    :: Word32
   , cur2Handle    :: Word32   -- ^ if 0, turns the cursor off
   , cur2HotX      :: Int32
   , cur2HotY      :: Int32
   } deriving Generic

instance CStorable Cursor2Struct
instance Storable  Cursor2Struct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_crtc_lut
data ControllerLutStruct = ControllerLutStruct
   { clsCrtcId       :: Word32
   , clsGammaSize    :: Word32
   , clsRed          :: Word64
   , clsGreen        :: Word64
   , clsBlue         :: Word64
   } deriving Generic

instance CStorable ControllerLutStruct
instance Storable  ControllerLutStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke


data ModePageFlip
   = PageFlipEvent
   | PageFlipAsync
   deriving (Show,Eq,Enum)

instance EnumBitSet ModePageFlip

-- | Data matching the C structure drm_mode_crtc_page_flip
data PageFlipStruct = PageFlipStruct
   { pfCrtcId        :: Word32
   , pfFbId          :: Word32
   , pfFlags         :: Word32
   , pfReserved      :: Word32
   , pfUserData      :: Word64
   } deriving Generic

instance CStorable PageFlipStruct
instance Storable  PageFlipStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_create_dumb
data CreateGenericStruct = CreateGenericStruct
   { cdHeight        :: Word32
   , cdWidth         :: Word32
   , cdBPP           :: Word32
   , cdFlags         :: Word32
   , cdHandle        :: Word32
   , cdPitch         :: Word32
   , cdSize          :: Word64
   } deriving Generic

instance CStorable CreateGenericStruct
instance Storable  CreateGenericStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_map_dumb
data MapGenericStruct = MapGenericStruct
   { mdHandle        :: Word32
   , mdPad           :: Word32
   , mdOffset        :: Word64
   } deriving Generic

instance CStorable MapGenericStruct
instance Storable  MapGenericStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke

-- | Data matching the C structure drm_mode_destroy_dumb
data DestroyGenericStruct = DestroyGenericStruct
   { ddHandle     :: Word32
   } deriving Generic

instance CStorable DestroyGenericStruct
instance Storable  DestroyGenericStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   peek        = cPeek
   poke        = cPoke
