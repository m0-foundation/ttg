/// CVL simple implementations of IERC20:
/// token => account => balance
persistent ghost mapping(address => mapping(address => uint256)) balanceByToken;
/// token => owner => spender => allowance
persistent ghost mapping(address => mapping(address => mapping(address => uint256))) allowanceByToken;

function tokenBalanceOf(address token, address account) returns uint256 {
    return balanceByToken[token][account];
}

function transferFromCVL(address token, address spender, address from, address to, uint256 amount) returns bool {
    if (allowanceByToken[token][from][spender] < amount) return false;
    /// @note while `transferCVL()` can still revert and return false, the allowance is still updated nevertheless.
    allowanceByToken[token][from][spender] = assert_uint256(allowanceByToken[token][from][spender] - amount);
    return transferCVL(token, from, to, amount);
}

function transferCVL(address token, address from, address to, uint256 amount) returns bool {
    if(balanceByToken[token][from] < amount) return false;
    balanceByToken[token][from] = assert_uint256(balanceByToken[token][from] - amount);
    balanceByToken[token][to] = require_uint256(balanceByToken[token][to] + amount);  // We neglect overflows.
    return true;
}
