// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {console} from "forge-std/Script.sol";
import {BaseScript} from "script/shared/Base.s.sol";
import {SPOG, SPOGGovernorBase} from "src/factories/SPOGFactory.sol";
import {SPOGFactory} from "src/factories/SPOGFactory.sol";
import {SPOGGovernorFactory} from "src/factories/SPOGGovernorFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {SPOGGovernor} from "src/core/governance/SPOGGovernor.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
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
    SPOGFactory public spogFactory;
    SPOGGovernorFactory public governorFactory;
    SPOG public spog;
    ERC20Mock public cash;
    uint256[2] public taxRange;
    uint256 public inflator;
    uint256 public time;
    uint256 public voteQuorum;
    uint256 public valueQuorum;
    uint256 public valueFixedInflationAmount;
    uint256 public tax;
    SPOGGovernor public voteGovernor;
    SPOGGovernor public valueGovernor;
    ERC20PricelessAuction public auctionImplementation;
    VoteToken public vote;
    ValueToken public value;

    VoteVault public voteVault;
    ValueVault public valueVault;

    uint256 public spogCreationSalt = createSalt("Simple Participatory Onchain Governance");

    function setUp() public override {
        super.setUp();

        vm.startBroadcast(deployer);

        // for the actual deployment, we will use an ERC20 token for cash
        cash = new ERC20Mock("CashToken", "cash", msg.sender, 100e18); // mint 10 tokens to msg.sender

        taxRange = [uint256(0), 6e18];
        inflator = 5;
        time = 10; // in blocks
        voteQuorum = 4;
        valueQuorum = 4;
        tax = 5e18;

        value = new ValueToken("SPOGValue", "value");
        vote = new VoteToken("SPOGVote", "vote", address(value));

        valueFixedInflationAmount = 100 * 10 ** SPOGVotes(address(value)).decimals();

        governorFactory = new SPOGGovernorFactory();

        // predict vote governor address
        bytes memory voteGovernorBytecode = governorFactory.getBytecode(vote, voteQuorum, time, "VoteGovernor");
        uint256 voteGovernorSalt = createSalt("VoteGovernor");
        address voteGovernorAddress = governorFactory.predictSPOGGovernorAddress(voteGovernorBytecode, voteGovernorSalt);

        // predict value governor address
        bytes memory valueGovernorBytecode = governorFactory.getBytecode(value, valueQuorum, time, "ValueGovernor");
        uint256 valueGovernorSalt = createSalt("ValueGovernor");
        address valueGovernorAddress =
            governorFactory.predictSPOGGovernorAddress(valueGovernorBytecode, valueGovernorSalt);

        auctionImplementation = new ERC20PricelessAuction();

        voteVault =
        new VoteVault(SPOGGovernorBase(payable(address(voteGovernorAddress))), IERC20PricelessAuction(auctionImplementation));
        valueVault = new ValueVault(SPOGGovernorBase(payable(address(valueGovernorAddress))));

        // deploy vote and value governors from factory
        voteGovernor = governorFactory.deploy(vote, voteQuorum, time, "VoteGovernor", voteGovernorSalt);
        valueGovernor = governorFactory.deploy(value, valueQuorum, time, "ValueGovernor", valueGovernorSalt);

        // sanity check
        assert(address(voteGovernor) == voteGovernorAddress); // SPOG vote governor address mismatch
        assert(address(valueGovernor) == valueGovernorAddress); // SPOG value governor address mismatch

        // grant minter role for test runner
        IAccessControl(address(vote)).grantRole(vote.MINTER_ROLE(), msg.sender);
        IAccessControl(address(value)).grantRole(value.MINTER_ROLE(), msg.sender);

        spogFactory = new SPOGFactory();

        bytes memory initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        // predict spog address
        bytes memory bytecode = spogFactory.getBytecode(
            initSPOGData,
            IVoteVault(voteVault),
            IValueVault(valueVault),
            time,
            voteQuorum,
            valueQuorum,
            valueFixedInflationAmount,
            SPOGGovernorBase(payable(address(voteGovernor))),
            SPOGGovernorBase(payable(address(valueGovernor)))
        );

        address spogAddress = spogFactory.predictSPOGAddress(bytecode, spogCreationSalt);
        console.log("predicted SPOG address: ", spogAddress);

        vm.stopBroadcast();
    }

    function run() public {
        setUp();

        vm.startBroadcast(deployer);

        bytes memory initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        spog = spogFactory.deploy(
            initSPOGData,
            IVoteVault(voteVault),
            IValueVault(valueVault),
            time,
            voteQuorum,
            valueQuorum,
            valueFixedInflationAmount,
            SPOGGovernorBase(payable(address(voteGovernor))),
            SPOGGovernorBase(payable(address(valueGovernor))),
            spogCreationSalt
        );

        console.log("SPOG address: ", address(spog));
        console.log("SPOGFactory address: ", address(spogFactory));
        console.log("SPOGVote token address: ", address(vote));
        console.log("SPOGValue token address: ", address(value));
        console.log("SPOGGovernor for $VOTE address : ", address(voteGovernor));
        console.log("SPOGGovernor for $VALUE address : ", address(valueGovernor));
        console.log("Cash address: ", address(cash));
        console.log("Vote holders vault address: ", address(voteVault));
        console.log("Value holders vault address: ", address(valueVault));

        vm.stopBroadcast();
    }

    function createSpog() public returns (SPOG) {
        setUp();

        bytes memory initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        SPOG newSpog = spogFactory.deploy(
            initSPOGData,
            IVoteVault(voteVault),
            IValueVault(valueVault),
            time,
            voteQuorum,
            valueQuorum,
            valueFixedInflationAmount,
            SPOGGovernorBase(payable(address(voteGovernor))),
            SPOGGovernorBase(payable(address(valueGovernor))),
            spogCreationSalt
        );

        return newSpog;
    }

    function createSalt(string memory saltValue) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(saltValue, address(this), block.timestamp, block.number)));
    }
}
