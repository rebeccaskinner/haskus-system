{-# LANGUAGE DeriveGeneric, ScopedTypeVariables #-}
module ViperVM.Arch.X86_64.Linux.Time
   ( TimeSpec(..)
   , Clock(..)
   , sysClockGetTime
   , sysClockSetTime
   , sysClockGetResolution
   , SleepResult(..)
   , sysNanoSleep
   , nanoSleep
   )
where

import Foreign.Storable
import Foreign.CStorable
import Data.Int
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (Ptr)
import Control.Applicative ((<$>))

import GHC.Generics (Generic)

import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.X86_64.Linux.Syscall

data TimeSpec = TimeSpec {
   tsSeconds      :: Int64,
   tsNanoSeconds  :: Int64
} deriving (Show,Eq,Ord,Generic)

instance CStorable TimeSpec
instance Storable TimeSpec where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   poke        = cPoke
   peek        = cPeek

data Clock
   = ClockWall             -- ^ System-wide wall clock
   | ClockMonotonic        -- ^ Monotonic clock from unspecified starting point
   | ClockProcess          -- ^ Per-process CPU-time clock (CPU time consumed by all threads in the process)
   | ClockThread           -- ^ Thread-specific CPU-time clock
   | ClockRawMonotonic     -- ^ Hardware-based monotonic clock
   | ClockCoarseWall       -- ^ Faster but less precise wall clock
   | ClockCoarseMonotonic  -- ^ Faster but less precise monotonic clock
   | ClockBoot             -- ^ Monotonic clock that includes any time that the system is suspended
   | ClockWallAlarm        -- ^ Like wall clock, but timers on this clock can wake-up a suspended system
   | ClockBootAlarm        -- ^ Like boot clock, but timers on this clock can wake-up a suspended system
   | ClockTAI              -- ^ Like wall clock but in International Atomic Time
   deriving (Show,Eq,Ord)

instance Enum Clock where
   fromEnum x = case x of
      ClockWall             -> 0
      ClockMonotonic        -> 1
      ClockProcess          -> 2
      ClockThread           -> 3
      ClockRawMonotonic     -> 4
      ClockCoarseWall       -> 5
      ClockCoarseMonotonic  -> 6
      ClockBoot             -> 7
      ClockWallAlarm        -> 8
      ClockBootAlarm        -> 9
      ClockTAI              -> 11
   toEnum x = case x of
      0  -> ClockWall
      1  -> ClockMonotonic
      2  -> ClockProcess
      3  -> ClockThread
      4  -> ClockRawMonotonic
      5  -> ClockCoarseWall
      6  -> ClockCoarseMonotonic
      7  -> ClockBoot
      8  -> ClockWallAlarm
      9  -> ClockBootAlarm
      11 -> ClockTAI
      _  -> error "Unknown clock"

-- | Retrieve clock time
sysClockGetTime :: Clock -> SysRet TimeSpec
sysClockGetTime clk =
   alloca $ \(t :: Ptr TimeSpec) ->
      onSuccessIO (syscall2 228 (fromEnum clk) t) (const $ peek t)

-- | Set clock time
sysClockSetTime :: Clock -> TimeSpec -> SysRet ()
sysClockSetTime clk time =
   with time $ \(t :: Ptr TimeSpec) ->
      onSuccess (syscall2 227 (fromEnum clk) t) (const ())

-- | Retrieve clock resolution
sysClockGetResolution :: Clock -> SysRet TimeSpec
sysClockGetResolution clk =
   alloca $ \(t :: Ptr TimeSpec) ->
      onSuccessIO (syscall2 229 (fromEnum clk) t) (const $ peek t)

data SleepResult
   = WokenUp TimeSpec   -- ^ Woken up by a signal, returns the remaining time to sleep
   | CompleteSleep      -- ^ Sleep completed
   deriving (Show,Eq,Ord)

-- | Suspend the calling thread for the specified amount of time
--
-- Can be interrupted by a signal (in this case it returns the remaining time)
sysNanoSleep :: TimeSpec -> SysRet SleepResult
sysNanoSleep ts =
   with ts $ \ts' ->
      alloca $ \(rem' :: Ptr TimeSpec) -> do
         ret <- syscall2 35 ts' rem'
         case defaultCheck ret of
            Nothing    -> return (Right CompleteSleep)
            Just EINTR -> Right . WokenUp <$> peek rem'
            Just err   -> return (Left err)

-- | Suspend the calling thread for the specified amount of time
--
-- When interrupted by a signal, suspend again for the remaining amount of time
nanoSleep :: TimeSpec -> SysRet ()
nanoSleep ts = do
   ret <- sysNanoSleep ts
   case ret of
      Left err            -> return (Left err)
      Right CompleteSleep -> return (Right ())
      Right (WokenUp r)   -> nanoSleep r
