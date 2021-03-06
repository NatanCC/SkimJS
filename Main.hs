import qualified Language.ECMAScript3.Parser as Parser
import Language.ECMAScript3.Syntax
import Control.Monad hiding (empty)
import Control.Applicative hiding (empty)
import Data.Map as Map
import Debug.Trace
import Value

--
-- Evaluate functions
--

evalExpr :: StateT -> Expression -> StateTransformer Value
evalExpr env (VarRef (Id id)) = stateLookup env id
evalExpr env (IntLit int) = return $ Int int
evalExpr env (InfixExpr op expr1 expr2) = do
    v1 <- evalExpr env expr1
    v2 <- evalExpr env expr2
    infixOp env op v1 v2
evalExpr env (AssignExpr OpAssign (LVar var) expr) = do
    v <- stateLookup env var
    case v of
        -- Variable not defined :(
        (Error _) -> return $ Error $ (show var) ++ " not defined"
        -- Variable defined, let's set its value
        _ -> do
            e <- evalExpr env expr
            setVar var e

{- 
{-}                                          CALL EXPR                                      -}
evalExpr env (CallExpr funcName funcParam) = do
    v <- stateLookup env funcName
    case v of
        (Error _) -> return $ Error $ (show var) ++ " not defined"
        (VarFunc funcName' funcParam' funcBody) -> do
            envP <- union env

evalParam :: StateT -> [String] -> [Expression] -> StateTransformer Value
evalParam env (paramName:xs) (paramExpr:ys) = do
    v <- setVar paramName (evalExpr paramExpr)
    evalParam v xs ys
evalParam env [] _ = ST (env -> ((), env))


-}



evalStmt :: StateT -> Statement -> StateTransformer Value
evalStmt env EmptyStmt = return Nil
evalStmt env (VarDeclStmt []) = return Nil
evalStmt env (VarDeclStmt (decl:ds)) =
    varDecl env decl >> evalStmt env (VarDeclStmt ds)
evalStmt env (ExprStmt expr) = evalExpr env expr
evalStmt env (FunctionStmt name {-Id-} args {-[Id]-} body {-[Statement]-}) = return $ VarFunc name args body
evalStmt env (BlockStmt []) = return Nil
evalStmt env (BlockStmt (x:xs)) = evalStmt env x >> evaluate env xs
--Começa aqui o IfSingleStmt
evalStmt env (IfSingleStmt expr stmt) = do
    ret <- evalExpr env expr
    case ret of
        (Bool b) -> if b then evalStmt env stmt else return Nil
    {-if ret == True then evalStmt env stmt
        else return Nil-}
--Começa aqui o IfStmt
evalStmt env (IfStmt expr stmt1 stmt2) = do
    ret <- evalExpr env expr
    case ret of
        (Bool b) -> if b then evalStmt env stmt1 else evalStmt env stmt2
------------------------------------------------------ FOR STMT ------------------------------------------------------
evalStmt env (ForStmt init test increment body) = do
    varDeclFor env init
    ret <- evalExpr env test
    case ret of
        (Bool b) -> if b then evalStmt env body else return Nil
    evalExpr env increment




varDeclFor :: StateT -> ForInit -> StateTransformer Value
varDeclFor env forinitdecl = do
    case forinitdecl of
        (NoInit) -> return Nil
        (VarInit (varDeclInit:xs)) -> varDecl env varDeclInit >> varDeclFor env (VarInit xs)
        (ExprInit exprInit) -> evalExpr env exprInit


{-
orStmt ForInit                                                      data VarDecl = VarDecl Id (Maybe Expression) 
            (Maybe Expression) -- test
            (Maybe Expression) -- increment
            Statement          -- body 
    -- ^ @ForStmt a init test increment body@, @for (init; test,
-}
{-

-- | for initializer, spec 12.6
data ForInit = NoInit -- ^ empty
               | VarInit [VarDecl] -- ^ @var x, y=42@
               | ExprInit Expression -- ^ @expr@
  deriving (Show,Data,Typeable,Eq,Ord)

-}




-- Do not touch this one :)
evaluate :: StateT -> [Statement] -> StateTransformer Value
evaluate env [] = return Nil
evaluate env [stmt] = evalStmt env stmt
evaluate env (s:ss) = evalStmt env s >> evaluate env ss

--
-- Operators
--

infixOp :: StateT -> InfixOp -> Value -> Value -> StateTransformer Value
infixOp env OpAdd  (Int  v1) (Int  v2) = return $ Int  $ v1 + v2
infixOp env OpSub  (Int  v1) (Int  v2) = return $ Int  $ v1 - v2
infixOp env OpMul  (Int  v1) (Int  v2) = return $ Int  $ v1 * v2
infixOp env OpDiv  (Int  v1) (Int  v2) = return $ Int  $ div v1 v2
infixOp env OpMod  (Int  v1) (Int  v2) = return $ Int  $ mod v1 v2
infixOp env OpLT   (Int  v1) (Int  v2) = return $ Bool $ v1 < v2
infixOp env OpLEq  (Int  v1) (Int  v2) = return $ Bool $ v1 <= v2
infixOp env OpGT   (Int  v1) (Int  v2) = return $ Bool $ v1 > v2
infixOp env OpGEq  (Int  v1) (Int  v2) = return $ Bool $ v1 >= v2
infixOp env OpEq   (Int  v1) (Int  v2) = return $ Bool $ v1 == v2
infixOp env OpNEq  (Bool v1) (Bool v2) = return $ Bool $ v1 /= v2
infixOp env OpLAnd (Bool v1) (Bool v2) = return $ Bool $ v1 && v2
infixOp env OpLOr  (Bool v1) (Bool v2) = return $ Bool $ v1 || v2

infixOp env op (Var x) v2 = do
    var <- stateLookup env x
    case var of
        error@(Error _) -> return error
        val -> infixOp env op val v2

infixOp env op v1 (Var x) = do
    var <- stateLookup env x
    case var of
        error@(Error _) -> return error
        val -> infixOp env op v1 val

--
-- Environment and auxiliary functions
--

environment :: Map String Value
environment = empty

stateLookup :: StateT -> String -> StateTransformer Value
stateLookup env var = ST $ \s ->
    (maybe
        (Error $ "Variable " ++ show var ++ " not defined")
        id
        (Map.lookup var (union s env)),
    s)

varDecl :: StateT -> VarDecl -> StateTransformer Value
varDecl env (VarDecl (Id id) maybeExpr) = do
    case maybeExpr of
        Nothing -> setVar id Nil
        (Just expr) -> do
            val <- evalExpr env expr
            setVar id val

setVar :: String -> Value -> StateTransformer Value -- Só para ambientes globais, se já existir ele substitui!!!!
setVar var val = ST $ \s -> (val, insert var val s)

--
-- Types and boilerplate
--

type StateT = Map String Value
data StateTransformer t = ST (StateT -> (t, StateT))

instance Monad StateTransformer where
    return x = ST $ \s -> (x, s)
    (>>=) (ST m) f = ST $ \s ->
        let (v, newS) = m s
            (ST resF) = f v
        in resF newS

instance Functor StateTransformer where
    fmap = liftM

instance Applicative StateTransformer where
    pure = return
    (<*>) = ap

--
-- Main and results functions
--

showResult :: (Value, StateT) -> String
showResult (val, defs) = show val ++ "\n" ++ show (toList defs) ++ "\n"

getResult :: StateTransformer Value -> (Value, StateT)
getResult (ST f) = f empty

main :: IO ()
main = do
    js <- Parser.parseFromFile "Main.js"
    let statements = unJavaScript js
    putStrLn $ "AST: " ++ (show $ statements) ++ "\n"
    putStr $ showResult $ getResult $ evaluate environment statements
