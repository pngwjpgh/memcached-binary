
--------------------------------------------------------------------------------

get :: Key -> I.Connection -> IO (HasReturn (Flags, Value))
get = I.useConnection . I.get (\f v -> successHasReturn (f,v)) failureHasReturn

get_ :: Key -> I.Connection -> IO (HasReturn Value)
get_ = I.useConnection . I.get (\_ v -> successHasReturn v) failureHasReturn

--------------------------------------------------------------------------------

setAddReplace :: OpCode -> Flags -> Expiry
              -> Key -> Value -> I.Connection -> IO NoReturn
setAddReplace op = \f e key value -> I.useConnection $
    I.setAddReplace successNoReturn failureNoReturn op (CAS 0) key value f e


set :: Flags -> Expiry -> Key -> Value -> I.Connection -> IO NoReturn
set = setAddReplace opSet

add :: Flags -> Expiry -> Key -> Value -> I.Connection -> IO NoReturn
add = setAddReplace opAdd

replace :: Flags -> Expiry -> Key -> Value -> I.Connection -> IO NoReturn
replace = setAddReplace opReplace

--------------------------------------------------------------------------------

delete :: Key -> I.Connection -> IO NoReturn
delete = I.useConnection . I.delete successNoReturn failureNoReturn (CAS 0)

--------------------------------------------------------------------------------

-- | modify value in transaction.
modify :: Expiry -> Key -> (Flags -> Value -> (Flags, Value, a))
       -> I.Connection -> IO (HasReturn a)
modify e key fn = I.useConnection $ \h ->
    I.getWithCAS (\c f v -> 
        let (f', v', r) = fn f v
        in I.setAddReplaceWithCAS (const $ successHasReturn r)
            failureHasReturn opSet c key v' f' e h
    ) failureHasReturn key h

-- | modify value in transaction.
modify_ :: Expiry
        -> Key -> (Flags -> Value -> (Flags, Value))
        -> I.Connection -> IO NoReturn
modify_ e key fn = I.useConnection $ \h ->
    I.getWithCAS (\c f v -> 
        let (f', v') = fn f v
        in I.setAddReplaceWithCAS (const $ successNoReturn)
            failureNoReturn opSet c key v' f' e h
    ) failureNoReturn key h

--------------------------------------------------------------------------------

incrDecr :: OpCode -> Expiry
         -> Key -> Delta -> Initial -> I.Connection -> IO (HasReturn Counter)
incrDecr op e k d i = I.useConnection $
    I.incrDecr successHasReturn failureHasReturn op (CAS 0) k d i e

increment :: Expiry -> Key -> Delta -> Initial
          -> I.Connection -> IO (HasReturn Counter)
increment = incrDecr opIncrement

decrement :: Expiry -> Key -> Delta -> Initial
          -> I.Connection -> IO (HasReturn Counter)
decrement = incrDecr opDecrement

--------------------------------------------------------------------------------

-- | flush all value.
flushAll :: I.Connection -> IO NoReturn
flushAll = I.useConnection $ I.flushAll successNoReturn failureNoReturn

--------------------------------------------------------------------------------

version :: I.Connection -> IO (HasReturn Version)
version = I.useConnection $ I.version (\s -> case readVersion s of
    Nothing -> failureHasReturn VersionParseFailed
    Just v  -> successHasReturn v) failureHasReturn
  where
    readVersion s0 = do
        (x, s1) <- S8.readInt s0
        when (S8.null s1) $ Nothing
        (y, s2) <- S8.readInt (S8.tail s1)
        when (S8.null s2) $ Nothing
        (z, s3) <- S8.readInt (S8.tail s2)
        unless (S8.null s3) $ Nothing
        return (Version [x,y,z] [])


-- | get version string.
versionString :: I.Connection -> IO (HasReturn S.ByteString)
versionString = I.useConnection $ I.version successHasReturn failureHasReturn

--------------------------------------------------------------------------------

-- | noop(use for keepalive).
noOp :: I.Connection -> IO NoReturn
noOp = I.useConnection $ I.noOp successNoReturn failureNoReturn

--------------------------------------------------------------------------------

appendPrepend :: OpCode -> Key -> Value -> I.Connection -> IO NoReturn
appendPrepend o = \k v -> I.useConnection $
    I.appendPrepend successNoReturn failureNoReturn o (CAS 0) k v

append :: Key -> Value -> I.Connection -> IO NoReturn
append  = appendPrepend opAppend

prepend :: Key -> Value -> I.Connection -> IO NoReturn
prepend = appendPrepend opPrepend

--------------------------------------------------------------------------------

-- | change expiry.
touch :: Expiry -> Key -> I.Connection -> IO NoReturn
touch e k = I.useConnection $
    I.touch (\_ _ -> successNoReturn) failureNoReturn opTouch k e

-- | get value/change expiry. 
getAndTouch :: Expiry -> Key -> I.Connection -> IO (HasReturn (Flags, Value))
getAndTouch e k = I.useConnection $
    I.touch (\f v -> successHasReturn (f,v)) failureHasReturn opGAT k e

-- | get value/change expiry. 
getAndTouch_ :: Expiry -> Key -> I.Connection -> IO (HasReturn Value)
getAndTouch_ e k = I.useConnection $
    I.touch (\_ v -> successHasReturn v) failureHasReturn opGAT k e
