// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";

contract Vault_IntegratedWithSPOG is SPOG_Base {
    address alice = createUser("alice");
    address bob = createUser("bob");
    address carol = createUser("carol");

    uint256 spogVoteAmountToMint = 1000e18;
    uint8 noVote = 0;
    uint8 yesVote = 1;

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
        uint256 proposalId = voteGovernor.hashProposal(targets, values, calldatas, hashedDescription);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }
}
