// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {console} from "forge-std/Script.sol";
import {BaseScript} from "script/shared/Base.s.sol";
import {SPOG} from "src/SPOGFactory.sol";
import {SPOGFactory} from "src/SPOGFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {GovSPOG} from "src/GovSPOG.sol";
import {IGovSPOG} from "src/interfaces/IGovSPOG.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SPOGDeployScript is BaseScript {
    SPOGFactory public factory;
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

    uint256 salt =
        uint256(
            keccak256(
                abi.encodePacked(
                    "Simple Participatory Onchain Governance",
                    address(this),
                    block.timestamp,
                    block.number
                )
            )
        );

    function triggerSetUp() public {
        // for the real deployment, we will use the real cash token
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

        govSPOGVote = new GovSPOG(vote, voteQuorum, voteTime, "GovSPOGVote");
        govSPOGValue = new GovSPOG(
            value,
            valueQuorum,
            forkTime,
            "GovSPOGValue"
        );

        // grant minter role to govSPOG
        IAccessControl(address(vote)).grantRole(
            vote.MINTER_ROLE(),
            address(govSPOGVote)
        );
        IAccessControl(address(value)).grantRole(
            value.MINTER_ROLE(),
            address(govSPOGValue)
        );

        factory = new SPOGFactory();

        // predict spog address
        bytes memory bytecode = factory.getBytecode(
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

        address spogAddress = factory.predictSPOGAddress(bytecode, salt);
        console.log("predicted SPOG address: ", spogAddress);
    }

    function run() public broadcaster {
        triggerSetUp();

        spog = factory.deploy(
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
            salt
        );

        console.log("SPOG address: ", address(spog));
        console.log("SPOGFactory address: ", address(factory));
        console.log("SPOGVote address: ", address(vote));
        console.log("SPOGValue address: ", address(value));
        console.log("GovSPOG for $VOTE address : ", address(govSPOGVote));
        console.log("GovSPOG for $VALUE address : ", address(govSPOGValue));
        console.log("Cash address: ", address(cash));
    }
}
