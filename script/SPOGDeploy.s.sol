// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {SPOG} from "src/SPOGFactory.sol";
import {SPOGFactory} from "src/SPOGFactory.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";
import {ISPOGVote} from "src/interfaces/ISPOGVote.sol";
import {SPOGVote} from "src/tokens/SPOGVote.sol";
import {GovSPOG} from "src/GovSPOG.sol";
import {IGovSPOG} from "src/interfaces/IGovSPOG.sol";

contract SPOGDeployScript is Script {
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
    GovSPOG public govSPOG;
    ISPOGVote public vote;

    uint256 salt =
        uint256(
            keccak256(
                abi.encodePacked(
                    "Simple Participatory Onchain Gorvenance",
                    address(this)
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

        factory = new SPOGFactory();

        vote = new SPOGVote("SPOGVote", "vote");
        govSPOG = new GovSPOG(vote, 0, 0);

        // bytes memory bytecode = factory.getBytecode(
        //     address(cash),
        //     taxRange,
        //     inflator,
        //     reward,
        //     voteTime,
        //     inflatorTime,
        //     sellTime,
        //     forkTime,
        //     voteQuorum,
        //     valueQuorum,
        //     tax,
        //     IGovSPOG(address(govSPOG))
        // );

        // address spogAddress = factory.predictSPOGAddress(bytecode, salt);

        // console.log("predicted SPOG address: ", spogAddress);
    }

    function run() public {
        vm.startBroadcast();

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
            IGovSPOG(address(govSPOG)),
            salt
        );

        console.log("SPOG address: ", address(spog));
        console.log("SPOGFactory address: ", address(factory));
        console.log("SPOGVote address: ", address(vote));
        console.log("GovSPOG address : ", address(govSPOG));
        console.log("Cash address: ", address(cash));
        vm.stopBroadcast();
    }
}
