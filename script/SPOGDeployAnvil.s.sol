// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {console} from "forge-std/Script.sol";
import {BaseScript} from "script/shared/Base.s.sol";
import {SPOG} from "src/factories/SPOGFactory.sol";
import {SPOGFactory} from "src/factories/SPOGFactory.sol";
import {SPOGGovernorFactory} from "src/factories/SPOGGovernorFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {SPOGGovernor} from "src/core/SPOGGovernor.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20PricelessAuction} from "src/periphery/ERC20PricelessAuction.sol";
import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";
import {Vault} from "src/periphery/Vault.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";

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
    Vault public vault;

    uint256 public spogCreationSalt = createSalt("Simple Participatory Onchain Governance");

    address user1 = vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
    address user2 = vm.addr(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
    address user3 = vm.addr(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a);
    address user4 = vm.addr(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6);
    address user5 = vm.addr(0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a);
    address user6 = vm.addr(0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba);
    address user7 = vm.addr(0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e);
    address user8 = vm.addr(0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356);
    address user9 = vm.addr(0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97);
    address user10 = vm.addr(0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6);

    address[] public users = [user1, user2, user3, user4, user5, user6, user7, user8, user9, user10];

    function triggerSetUp() public {
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

        for (uint256 i = 0; i < users.length; i++) {
            cash.mint(users[i], 1e5 * 1e18);
            value.mint(users[i], 1e5 * 1e18);
            vote.mint(users[i], 1e5 * 1e18);
        }

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
        vault =
        new Vault(ISPOGGovernor(voteGovernorAddress), ISPOGGovernor(valueGovernorAddress), IERC20PricelessAuction(auctionImplementation));

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
            address(vault),
            time,
            voteQuorum,
            valueQuorum,
            valueFixedInflationAmount,
            ISPOGGovernor(address(voteGovernor)),
            ISPOGGovernor(address(valueGovernor))
        );

        address spogAddress = spogFactory.predictSPOGAddress(bytecode, spogCreationSalt);
        console.log("predicted SPOG address: ", spogAddress);
    }

    function run() public broadcaster {
        triggerSetUp();

        bytes memory initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        spog = spogFactory.deploy(
            initSPOGData,
            address(vault),
            time,
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
        console.log();
        console.log("Created 100,000 CASH, VALUE and VOTE for 10 default Anvil users");
    }

    function createSpog() public returns (SPOG) {
        triggerSetUp();

        bytes memory initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        SPOG newSpog = spogFactory.deploy(
            initSPOGData,
            address(vault),
            time,
            voteQuorum,
            valueQuorum,
            valueFixedInflationAmount,
            ISPOGGovernor(address(voteGovernor)),
            ISPOGGovernor(address(valueGovernor)),
            spogCreationSalt
        );

        return newSpog;
    }

    function createSalt(string memory saltValue) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(saltValue, address(this), block.timestamp, block.number)));
    }
}
