// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "script/shared/Base.s.sol";

import "src/core/SPOG.sol";
import "src/core/governor/DualGovernor.sol";
import "src/interfaces/tokens/ISPOGVotes.sol";
import "src/periphery/ERC20PricelessAuction.sol";
import "src/periphery/vaults/ValueVault.sol";
import "src/periphery/vaults/VoteVault.sol";
import "src/tokens/VoteToken.sol";
import "src/tokens/ValueToken.sol";

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
    address public voteVault;
    address public valueVault;
    address public auction;

    function setUp() public override {
        super.setUp();

        vm.startBroadcast(deployer);

        cash = address(new ERC20Mock("CashToken", "CASH", msg.sender, 100e18));

        inflator = 10; // 10%
        valueFixedInflation = 100 * 10e18;

        time = 100; // in blocks
        voteQuorum = 4; // 4%
        valueQuorum = 4; // 4%
        tax = 5e18;
        taxLowerBound = 0;
        taxUpperBound = 6e18;

        value = address(new ValueToken("SPOG Value", "$VALUE"));
        vote = address(new VoteToken("SPOG Vote", "$VOTE", value));
        auction = address(new ERC20PricelessAuction());

        // deploy governor and vaults
        governor = address(new DualGovernor("SPOG Governor", vote, value, voteQuorum, valueQuorum, time));
        voteVault = address(new VoteVault(governor, auction));
        valueVault = address(new ValueVault(governor));

        // grant minter role for test runner
        IAccessControl(vote).grantRole(ISPOGVotes(vote).MINTER_ROLE(), msg.sender);
        IAccessControl(value).grantRole(ISPOGVotes(value).MINTER_ROLE(), msg.sender);

        vm.stopBroadcast();
    }

    function run() public {
        setUp();

        vm.startBroadcast(deployer);

        spog = address(createSpog(false));

        console.log("SPOG address: ", spog);
        console.log("SPOGVote token address: ", vote);
        console.log("SPOGValue token address: ", value);
        console.log("DualGovernor address: ", governor);
        console.log("Cash address: ", cash);
        console.log("Vote holders vault address: ", voteVault);
        console.log("Value holders vault address: ", valueVault);

        vm.stopBroadcast();
    }

    function createSpog(bool runSetup) public returns (SPOG) {
        if (runSetup) {
            setUp();
        }

        SPOG.Configuration memory config = SPOG.Configuration(
            payable(address(governor)),
            address(voteVault),
            address(valueVault),
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
