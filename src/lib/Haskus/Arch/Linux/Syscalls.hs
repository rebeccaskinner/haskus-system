{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}

-- | Linux system calls (syscalls)
module Haskus.Arch.Linux.Syscalls
   ( syscall
   )
where

--TODO: use conditional import here when we will support different
--architectures
import Haskus.Arch.X86_64.Linux.Syscalls
