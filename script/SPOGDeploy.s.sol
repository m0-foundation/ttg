// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {console} from "forge-std/Script.sol";
import {BaseScript} from "script/shared/Base.s.sol";
import {SPOG} from "src/factories/SPOGFactory.sol";
import {SPOGFactory} from "src/factories/SPOGFactory.sol";
import {SPOGGovernorFactory} from "src/factories/SPOGGovernorFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {SPOGGovernor} from "src/core/SPOGGovernor.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Vault} from "src/periphery/Vault.sol";

contract SPOGDeployScript is BaseScript {
    SPOGFactory public spogFactory;
    SPOGGovernorFactory public governorFactory;
    SPOG public spog;
    ERC20Mock public cash;
    uint256[2] public taxRange;
    uint256 public inflator;
    uint256 public reward;
    uint256 public voteTime;
    uint256 public inflatorTime;
    uint256 public sellTime;
    uint256 public forkTime;
    uint256 public voteQuorum;
    uint256 public valueQuorum;
    uint256 public valueFixedInflationAmount;
    uint256 public tax;
    SPOGGovernor public voteGovernor;
    SPOGGovernor public valueGovernor;
    ISPOGVotes public vote;
    ISPOGVotes public value;
    Vault public vault;

    uint256 public spogCreationSalt = createSalt("Simple Participatory Onchain Governance");

    function triggerSetUp() public {
        // for the actual deployment, we will use an ERC20 token for cash
        cash = new ERC20Mock("CashToken", "cash", msg.sender, 10e18); // mint 10 tokens to msg.sender

        taxRange = [uint256(0), uint256(5)];
        inflator = 5;
        reward = 5;
        voteTime = 10; // in blocks
        inflatorTime = 10; // in blocks
        sellTime = 10; // in blocks
        forkTime = 10; // in blocks
        voteQuorum = 4;
        valueQuorum = 4;
        tax = 5;

        vote = new SPOGVotes("SPOGVote", "vote");
        value = new SPOGVotes("SPOGValue", "value");

        valueFixedInflationAmount = 100 * 10 ** SPOGVotes(address(value)).decimals();

        governorFactory = new SPOGGovernorFactory();

        // predict vote governor address
        bytes memory voteGovernorBytecode = governorFactory.getBytecode(vote, voteQuorum, voteTime, "VoteGovernor");
        uint256 voteGovernorSalt = createSalt("VoteGovernor");
        address voteGovernorAddress = governorFactory.predictSPOGGovernorAddress(voteGovernorBytecode, voteGovernorSalt);

        // predict value governor address
        bytes memory valueGovernorBytecode = governorFactory.getBytecode(value, valueQuorum, forkTime, "ValueGovernor");
        uint256 valueGovernorSalt = createSalt("ValueGovernor");
        address valueGovernorAddress =
            governorFactory.predictSPOGGovernorAddress(valueGovernorBytecode, valueGovernorSalt);

        vault = new Vault(ISPOGGovernor(voteGovernorAddress), ISPOGGovernor(valueGovernorAddress));

        // deploy vote and value governors from factory
        voteGovernor = governorFactory.deploy(vote, voteQuorum, voteTime, "VoteGovernor", voteGovernorSalt);
        valueGovernor = governorFactory.deploy(value, valueQuorum, voteTime, "ValueGovernor", valueGovernorSalt);

        // sanity check
        assert(address(voteGovernor) == voteGovernorAddress); // SPOG vote governor address mismatch
        assert(address(valueGovernor) == valueGovernorAddress); // SPOG value governor address mismatch

        // grant minter role to vote and value governors
        IAccessControl(address(vote)).grantRole(vote.MINTER_ROLE(), address(voteGovernor));
        IAccessControl(address(value)).grantRole(value.MINTER_ROLE(), address(valueGovernor));

        // grant minter role for test runner
        IAccessControl(address(vote)).grantRole(vote.MINTER_ROLE(), msg.sender);
        IAccessControl(address(value)).grantRole(value.MINTER_ROLE(), msg.sender);

        spogFactory = new SPOGFactory();

        bytes memory initSPOGData =
            abi.encode(address(cash), taxRange, inflator, reward, inflatorTime, sellTime, forkTime, tax);

        // predict spog address
        bytes memory bytecode = spogFactory.getBytecode(
            initSPOGData,
            address(vault),
            voteTime,
            voteQuorum,
            valueQuorum,
            valueFixedInflationAmount,
            ISPOGGovernor(address(voteGovernor)),
            ISPOGGovernor(address(valueGovernor))
        );

        address spogAddress = spogFactory.predictSPOGAddress(bytecode, spogCreationSalt);
        console.log("predicted SPOG address: ", spogAddress);

        vault.changeAdmin(spogAddress);
    }

    function run() public broadcaster {
        triggerSetUp();

        bytes memory initSPOGData =
            abi.encode(address(cash), taxRange, inflator, reward, inflatorTime, sellTime, forkTime, tax);

        spog = spogFactory.deploy(
            initSPOGData,
            address(vault),
            voteTime,
            voteQuorum,
            valueQuorum,
            valueFixedInflationAmount,
            ISPOGGovernor(address(voteGovernor)),
            ISPOGGovernor(address(valueGovernor)),
            spogCreationSalt
        );

        console.log("SPOG address: ", address(spog));
        console.log("SPOGFactory address: ", address(spogFactory));
        console.log("SPOGVote token address: ", address(vote));
        console.log("SPOGValue token address: ", address(value));
        console.log("SPOGGovernor for $VOTE address : ", address(voteGovernor));
        console.log("SPOGGovernor for $VALUE address : ", address(valueGovernor));
        console.log("Cash address: ", address(cash));
        console.log("Vault address: ", address(vault));
    }

    /**
     * Private Function *******
     */

    function createSalt(string memory saltValue) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(saltValue, address(this), block.timestamp, block.number)));
    }
}
