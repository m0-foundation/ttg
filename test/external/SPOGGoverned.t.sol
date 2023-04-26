// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {SPOGGoverned} from "src/external/SPOGGoverned.sol";
import {List} from "src/periphery/List.sol";
import {IList} from "src/interfaces/IList.sol";
import "forge-std/console.sol";

contract TestContract is SPOGGoverned {
    address public collateralManagersListAddress;

    constructor(address _spog, address _collateralManagers) SPOGGoverned(_spog) {
        // check spog approved on deploy
        collateralManagersListAddress = address(super.getListByAddress(_collateralManagers));
    }

    modifier onlyCollateralManagers() {
        require(collateralManagersList().contains(msg.sender), "SPOGGoverned: only collateral managers");

        _;
    }

    // check spog approved on each use
    function collateralManagersList() public view returns (IList) {
        return super.getListByAddress(collateralManagersListAddress);
    }

    function doAThing() public onlyCollateralManagers returns (bool) {
        return true;
    }
}

contract SPOGGovernedTest is SPOG_Base {
    address alice = createUser("alice");

    uint8 noVote = 0;
    uint8 yesVote = 1;

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function proposeAddingNewListToSpog(string memory proposalDescription, address list)
        private
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

        // create new proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_abstractSpogGoverned() public {
        // create new list
        // list has to have spog as admin
        List list = new List("Collateral Managers");
        list.add(alice);
        list.changeAdmin(address(spog));

        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("Add Collateral Managers List", address(list));

        // fast forward one epoch to propose
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        voteGovernor.castVote(proposalId, yesVote);

        // fast forward one epoch to execute
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // execute vote
        spog.execute(targets, values, calldatas, hashedDescription);

        TestContract testGovernedContract = new TestContract(address(spog), address(list));

        assertTrue(testGovernedContract.collateralManagersList().contains(alice));

        vm.expectRevert();
        testGovernedContract.doAThing();

        // only collateral mgr can doAThing()
        vm.prank(alice);
        assertTrue(testGovernedContract.doAThing());
    }
}
