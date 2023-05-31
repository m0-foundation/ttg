// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";
import "src/external/SPOGGoverned.sol";

interface IMockConfig {
    function someValue() external view returns (uint256);
}

contract MockConfig is IMockConfig, ERC165 {
    uint256 public immutable someValue = 1;

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IMockConfig).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract MockGovernedContract is SPOGGoverned {
    address public collateralManagersListAddress;

    constructor(address _spog, address _collateralManagers) SPOGGoverned(_spog) {
        // check spog approved on deploy
        collateralManagersListAddress = address(super.getListByAddress(_collateralManagers));
    }

    error OnlyCollateralManagers();

    modifier onlyCollateralManagers() {
        if (!collateralManagersList().contains(msg.sender)) revert OnlyCollateralManagers();
        _;
    }

    // check spog approved on each use
    function collateralManagersList() public view returns (IList) {
        return super.getListByAddress(collateralManagersListAddress);
    }

    function doAThing() public view onlyCollateralManagers returns (bool) {
        return true;
    }
}

contract MockGovernedContract2 is SPOGGoverned {
    constructor(address _spog) SPOGGoverned(_spog) {}

    function getValueFromConfig(bytes32 name) public view returns (uint256) {
        (address configAddress,) = super.getConfigByName(name);
        IMockConfig config = IMockConfig(configAddress);
        return config.someValue();
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
        calldatas[0] = abi.encodeWithSignature("addList(address)", list);
        string memory description = proposalDescription;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create new proposal
        cash.approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function proposeAddingConfigToSpog(
        string memory proposalDescription,
        bytes32 name,
        address contractAddress,
        bytes4 interfaceId
    ) private returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32) {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] =
            abi.encodeWithSignature("changeConfig(bytes32,address,bytes4)", name, contractAddress, interfaceId);
        string memory description = proposalDescription;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create new proposal
        cash.approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_abstractSpogGoverned_UsesLists() public {
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
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward one epoch to execute
        vm.roll(block.number + governor.votingDelay() + 1);

        // execute vote
        governor.execute(targets, values, calldatas, hashedDescription);

        MockGovernedContract testGovernedContract = new MockGovernedContract(address(spog), address(list));

        assertTrue(testGovernedContract.collateralManagersList().contains(alice));

        vm.expectRevert();
        testGovernedContract.getListByAddress(address(0));

        // only collateral mgr can doAThing()
        vm.prank(alice);
        assertTrue(testGovernedContract.doAThing());
    }

    function test_abstractSpogGoverned_UsesConfig() public {
        MockConfig config = new MockConfig();

        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingConfigToSpog(
            "Add MockConfig", keccak256("MockConfig"), address(config), type(IMockConfig).interfaceId
        );

        // fast forward one epoch to propose
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward one epoch to execute
        vm.roll(block.number + governor.votingDelay() + 1);

        // execute vote
        governor.execute(targets, values, calldatas, hashedDescription);

        MockGovernedContract2 testGovernedContract = new MockGovernedContract2(address(spog));

        uint256 someValue = testGovernedContract.getValueFromConfig(keccak256("MockConfig"));

        assertTrue(someValue == 1);
    }
}
