// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "script/shared/Base.s.sol";

import "src/core/SPOG.sol";
import "src/core/governor/DualGovernor.sol";
import "src/periphery/ERC20PricelessAuction.sol";
import "src/periphery/SPOGVault.sol";
import "src/tokens/VOTE.sol";
import "src/tokens/VALUE.sol";

contract SPOGDeployScript is BaseScript {
    address public governor;
    address public spog;

    uint256 public time;
    uint256 public voteQuorum;
    uint256 public valueQuorum;
    address public cash;
    uint256 public tax;
    uint256 public taxLowerBound;
    uint256 public taxUpperBound;
    uint256 public inflator;
    uint256 public valueFixedInflation;

    address public vote;
    address public value;
    address public vault;
    address public auction;

    function setUp() public override {
        super.setUp();

        vm.startBroadcast(deployer);

        cash = address(new ERC20Mock("CashToken", "CASH", msg.sender, 100e18));

        inflator = 20; // 20%
        valueFixedInflation = 100 * 10e18;

        time = 100; // in blocks
        voteQuorum = 4; // 4%
        valueQuorum = 4; // 4%
        tax = 5e18;
        taxLowerBound = 0;
        taxUpperBound = 6e18;

        value = address(new VALUE("SPOG Value", "VALUE"));
        vote = address(new VOTE("SPOG Vote", "VOTE", value));
        auction = address(new ERC20PricelessAuction());

        // deploy governor and vaults
        governor = address(new DualGovernor("DualGovernor", vote, value, voteQuorum, valueQuorum, time));
        vault = address(new SPOGVault(governor));

        // grant minter role for test runner
        IVOTE(vote).grantRole(IVOTE(vote).MINTER_ROLE(), msg.sender);
        IVALUE(value).grantRole(IVALUE(value).MINTER_ROLE(), msg.sender);

        vm.stopBroadcast();
    }

    function run() public {
        setUp();

        vm.startBroadcast(deployer);

        spog = address(createSpog(false));

        console.log("SPOG address: ", spog);
        console.log("VOTE token address: ", vote);
        console.log("VALUE token address: ", value);
        console.log("DualGovernor address: ", governor);
        console.log("Cash address: ", cash);
        console.log("Vault address: ", vault);

        vm.stopBroadcast();
    }

    function createSpog(bool runSetup) public returns (SPOG) {
        if (runSetup) {
            setUp();
        }

        SPOG.Configuration memory config = SPOG.Configuration(
            payable(address(governor)),
            address(vault),
            address(cash),
            tax,
            taxLowerBound,
            taxUpperBound,
            inflator,
            valueFixedInflation
        );

        SPOG newSpog = new SPOG(config);

        return newSpog;
    }
}
