// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {console} from "forge-std/Script.sol";
import {BaseScript} from "script/shared/Base.s.sol";
import {SPOGGovernor} from "src/core/governor/SPOGGovernor.sol";
import {SPOG} from "src/core/SPOG.sol";

import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {ERC20PricelessAuction} from "src/periphery/ERC20PricelessAuction.sol";
import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";
import {ValueVault} from "src/periphery/vaults/ValueVault.sol";
import {VoteVault} from "src/periphery/vaults/VoteVault.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";
import {IVoteToken} from "src/interfaces/tokens/IVoteToken.sol";
import {IValueToken} from "src/interfaces/tokens/IValueToken.sol";

contract SPOGDeployScript is BaseScript {
    SPOGGovernor public governor;
    uint256 public time;
    uint256 public voteQuorum;
    uint256 public valueQuorum;

    SPOG public spog;
    ERC20Mock public cash;
    uint256 public tax;
    uint256 public taxLowerBound;
    uint256 public taxUpperBound;
    uint256 public inflator;
    uint256 public valueFixedInflation;

    ERC20PricelessAuction public auctionImplementation;
    VoteToken public vote;
    ValueToken public value;
    VoteVault public voteVault;
    ValueVault public valueVault;

    //  struct Configuration {
    //     address payable governor;
    //     address voteVault;
    //     address valueVault;
    //     address cash;
    //     uint256 tax;
    //     uint256 taxLowerBound;
    //     uint256 taxUpperBound;
    //     uint256 inflator;
    //     uint256 valueFixedInflation;
    // }

    function setUp() public override {
        super.setUp();

        vm.startBroadcast(deployer);

        // for the actual deployment, we will use an ERC20 token for cash
        cash = new ERC20Mock("CashToken", "cash", msg.sender, 100e18); // mint 10 tokens to msg.sender

        inflator = 5;
        valueFixedInflation = 100 * 10e18;

        time = 10; // in blocks
        voteQuorum = 4;
        valueQuorum = 4;

        tax = 5e18;
        taxLowerBound = 0;
        taxUpperBound = 6e18;

        value = new ValueToken("SPOGValue", "value");
        vote = new VoteToken("SPOGVote", "vote", address(value));
        auctionImplementation = new ERC20PricelessAuction();

        // deploy governor
        governor = new SPOGGovernor("SPOGGovernor", address(vote), address(value), voteQuorum, valueQuorum, time);

        voteVault =
            new VoteVault(SPOGGovernor(payable(address(governor))), IERC20PricelessAuction(auctionImplementation));
        valueVault = new ValueVault(SPOGGovernor(payable(address(governor))));

        // grant minter role for test runner
        IAccessControl(address(vote)).grantRole(vote.MINTER_ROLE(), msg.sender);
        IAccessControl(address(value)).grantRole(value.MINTER_ROLE(), msg.sender);

        vm.stopBroadcast();
    }

    function run() public {
        setUp();

        vm.startBroadcast(deployer);

        spog = createSpog(false);

        console.log("SPOG address: ", address(spog));
        console.log("SPOGVote token address: ", address(vote));
        console.log("SPOGValue token address: ", address(value));
        console.log("SPOGGovernor address: ", address(governor));
        console.log("Cash address: ", address(cash));
        console.log("Vote holders vault address: ", address(voteVault));
        console.log("Value holders vault address: ", address(valueVault));

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
