import "./erc20.spec";

using DummyERC20A as tokenA;
using DummyERC20B as tokenB;

methods {
    function _.transfer(address token_, address to_, uint256 amount_) internal with(env e) => CVLTransfer(e, token_, to_, amount_) expect (bool);
    
    // In entry for isValidSignature(bytes32, bytes), the 2nd argument is a reference type with non-storage location specifier memory, which are not part of external (contract or library) method signatures
    // function _.isValidSignature(bytes32, bytes memory) external => DISPATCHER(true); 
}

function CVLTransfer(env e, address token_, address to_, uint256 amount_) returns bool {
    if (token_ == tokenA) {
        return tokenA.transfer(e, to_, amount_);
    } else {
        return tokenB.transfer(e, to_, amount_);
    }
}




rule sanity(method f)
{
	env e;
	calldataarg args;
	f(e,args);
	// satisfy true;
    assert false;
}