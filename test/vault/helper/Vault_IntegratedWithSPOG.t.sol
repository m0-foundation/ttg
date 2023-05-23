// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract Vault_IntegratedWithSPOG is SPOG_Base {
    address alice = createUser("alice");
    address bob = createUser("bob");
    address carol = createUser("carol");

    uint256 amountToMint = 100e18;
    uint8 noVote = 0;
    uint8 yesVote = 1;

    function setUp() public override {
        super.setUp();

        // mint ether and spogVote and spogValue to alice, bob and carol
        vm.deal({account: alice, newBalance: 100 ether});
        spogVote.mint(alice, amountToMint);
        spogValue.mint(alice, amountToMint);
        vm.startPrank(alice);
        spogVote.delegate(alice); // self delegate
        spogValue.delegate(alice); // self delegate
        vm.stopPrank();

        vm.deal({account: bob, newBalance: 100 ether});
        spogVote.mint(bob, amountToMint);
        spogValue.mint(bob, amountToMint);
        vm.startPrank(bob);
        spogVote.delegate(bob); // self delegate
        spogValue.delegate(bob); // self delegate
        vm.stopPrank();

        vm.deal({account: carol, newBalance: 100 ether});
        spogVote.mint(carol, amountToMint);
        spogValue.mint(carol, amountToMint);
        vm.startPrank(carol);
        spogVote.delegate(carol); // self delegate
        spogValue.delegate(carol); // self delegate
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function proposeAddingNewListToSpog(string memory proposalDescription)
        public
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = proposalDescription;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }
}
