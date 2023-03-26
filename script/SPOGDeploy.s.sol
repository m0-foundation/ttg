// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {console} from "forge-std/Script.sol";
import {BaseScript} from "script/shared/Base.s.sol";
import {SPOG} from "src/factories/SPOGFactory.sol";
import {SPOGFactory} from "src/factories/SPOGFactory.sol";
import {GovSPOGFactory} from "src/factories/GovSPOGFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {GovSPOG} from "src/core/GovSPOG.sol";
import {IGovSPOG} from "src/interfaces/IGovSPOG.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Vault} from "src/periphery/Vault.sol";

contract SPOGDeployScript is BaseScript {
    SPOGFactory public spogFactory;
    GovSPOGFactory public govSpogFactory;
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
    uint256 public tax;
    GovSPOG public govSPOGVote;
    GovSPOG public govSPOGValue;
    ISPOGVotes public vote;
    ISPOGVotes public value;
    Vault public vault;

    uint256 public spogCreationSalt =
        createSalt("Simple Participatory Onchain Governance");

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

        govSpogFactory = new GovSPOGFactory();

        // predict govSPOGVote address
        bytes memory govSPOGVotebytecode = govSpogFactory.getBytecode(
            vote,
            voteQuorum,
            voteTime,
            "GovSPOGVote"
        );
        uint256 govSPOGVoteSalt = createSalt("GovSPOGVote");
        address govSPOGVoteAddress = govSpogFactory.predictGovSPOGAddress(
            govSPOGVotebytecode,
            govSPOGVoteSalt
        );

        // predict govSPOGValue address
        bytes memory govSPOGValueBytecode = govSpogFactory.getBytecode(
            value,
            valueQuorum,
            forkTime,
            "GovSPOGValue"
        );
        uint256 govSPOGValueSalt = createSalt("GovSPOGValue");
        address govSPOGValueAddress = govSpogFactory.predictGovSPOGAddress(
            govSPOGValueBytecode,
            govSPOGValueSalt
        );

        vault = new Vault(govSPOGVoteAddress, govSPOGValueAddress);

        // deploy govSPOGVote and govSPOGValue from factory
        govSPOGVote = govSpogFactory.deploy(
            vote,
            voteQuorum,
            voteTime,
            "GovSPOGVote",
            govSPOGVoteSalt
        );

        govSPOGValue = govSpogFactory.deploy(
            value,
            valueQuorum,
            forkTime,
            "GovSPOGValue",
            govSPOGValueSalt
        );

        // sanity check
        assert(address(govSPOGVote) == govSPOGVoteAddress); // GovSPOGVote address mismatch
        assert(address(govSPOGValue) == govSPOGValueAddress); // GovSPOGValue address mismatch

        // grant minter role to govSPOG
        IAccessControl(address(vote)).grantRole(
            vote.MINTER_ROLE(),
            address(govSPOGVote)
        );
        IAccessControl(address(value)).grantRole(
            value.MINTER_ROLE(),
            address(govSPOGValue)
        );

        spogFactory = new SPOGFactory();

        // predict spog address
        bytes memory bytecode = spogFactory.getBytecode(
            address(vault),
            address(cash),
            taxRange,
            inflator,
            reward,
            voteTime,
            inflatorTime,
            sellTime,
            forkTime,
            voteQuorum,
            valueQuorum,
            tax,
            IGovSPOG(address(govSPOGVote)),
            IGovSPOG(address(govSPOGValue))
        );

        address spogAddress = spogFactory.predictSPOGAddress(
            bytecode,
            spogCreationSalt
        );
        console.log("predicted SPOG address: ", spogAddress);
    }

    function run() public broadcaster {
        triggerSetUp();

        spog = spogFactory.deploy(
            address(vault),
            address(cash),
            taxRange,
            inflator,
            reward,
            voteTime,
            inflatorTime,
            sellTime,
            forkTime,
            voteQuorum,
            valueQuorum,
            tax,
            IGovSPOG(address(govSPOGVote)),
            IGovSPOG(address(govSPOGValue)),
            spogCreationSalt
        );

        console.log("SPOG address: ", address(spog));
        console.log("SPOGFactory address: ", address(spogFactory));
        console.log("SPOGVote address: ", address(vote));
        console.log("SPOGValue address: ", address(value));
        console.log("GovSPOG for $VOTE address : ", address(govSPOGVote));
        console.log("GovSPOG for $VALUE address : ", address(govSPOGValue));
        console.log("Cash address: ", address(cash));
        console.log("Vault address: ", address(vault));
    }

    /******** Private Function ********/

    function createSalt(
        string memory saltValue
    ) private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        saltValue,
                        address(this),
                        block.timestamp,
                        block.number
                    )
                )
            );
    }
}
