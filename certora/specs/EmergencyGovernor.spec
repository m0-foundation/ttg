// import "./erc20.spec";


rule sanity(method f)
{
	env e;
	calldataarg args;
	f(e,args);
	// satisfy true;
    assert false;
}