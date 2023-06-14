// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import "script/shared/Base.s.sol";

import "src/core/SPOG.sol";
import "src/core/governor/DualGovernor.sol";
import "src/factories/ListFactory.sol";
import "src/interfaces/tokens/ISPOGVotes.sol";
import "src/periphery/ERC20PricelessAuction.sol";
import "src/periphery/vaults/ValueVault.sol";
import "src/periphery/vaults/VoteVault.sol";
import "src/tokens/VoteToken.sol";
import "src/tokens/ValueToken.sol";

import "forge-std/StdJson.sol";

contract SPOGDeployScript is BaseScript {
    using stdJson for string;

    // must be in alphabetical order
    struct DistributionList {
        string balance;
        address delegate;
        address recipient;
    }

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
    address public listFactory;

    bool public cashDeployed;

    function strToUint(string memory _str) public pure returns (uint256 res, bool err) {
        for (uint256 i = 0; i < bytes(_str).length; i++) {
            if ((uint8(bytes(_str)[i]) - 48) < 0 || (uint8(bytes(_str)[i]) - 48) > 9) {
                return (0, false);
            }
            res += (uint8(bytes(_str)[i]) - 48) * 10 ** (bytes(_str).length - i - 1);
        }

        return (res, true);
    }

    function deployCash() public returns (address) {
        cashDeployed = true;
        return address(new ERC20Mock("Fake WETH", "WETH", msg.sender, 0));
    }

    function mintTokensAndDelegate(address user, uint256 amount, address delegate) public {
        console.log("Minting", amount, "tokens for ", user);

        if (cashDeployed) {
            ERC20Mock(cash).mint(user, amount);
        }
        ISPOGVotes(value).mint(user, amount);
        ISPOGVotes(vote).mint(user, amount);

        console.log("Delegating on behalf of", user, "to ", delegate);

        ISPOGVotes(value).setInitialDelegate(user, delegate);
        ISPOGVotes(vote).setInitialDelegate(user, delegate);
    }

    function run() public broadcaster {
        inflator = 10; // 10%
        valueFixedInflation = 100 * 10e18;

        time = 100; // in blocks
        voteQuorum = 4; // 4%
        valueQuorum = 4; // 4%
        tax = 5e18;
        taxLowerBound = 0;
        taxUpperBound = 6e18;

        // use existing token or deploy new one
        cash = vm.envOr("WETH_ADDRESS", deployCash());

        value = address(new ValueToken("SPOG Value", "VALUE"));
        vote = address(new VoteToken("SPOG Vote", "VOTE", value));
        auction = address(new ERC20PricelessAuction());
        listFactory = address(new ListFactory());

        // read distribution list
        bool distributionListProvided;
        string memory distributionListText;
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/data/distributionList.json");
        console.log(string.concat("Looking for distribution list at: ", path));
        try vm.readFile(path) returns (string memory contents) {
            distributionListProvided = true;
            distributionListText = contents;
        } catch {
            console.log("Could not find distribution list");
            distributionListText = "";
        }

        // mint before governor deploy to be in first snapshot
        if (!distributionListProvided) {
            if (keccak256(bytes(_mnemonic)) == keccak256(bytes(_TEST_MNEMONIC))) {
                console.log(string.concat("Deploying and minting tokens using test mnemonic: ", _TEST_MNEMONIC));
            } else {
                console.log("Deploying and minting tokens using provided mnemonic in env $MNEMONIC");
            }

            for (uint32 i; i <= 5; i++) {
                (address user,) = deriveRememberKey(_mnemonic, i);
                // self delegates when using mnemonic
                mintTokensAndDelegate(user, 100_000e18, user);
            }
        } else {
            console.log("Minting tokens using distributionList.json");

            try vm.parseJson(distributionListText) returns (bytes memory json) {
                console.log("Read distribution json");
                DistributionList[] memory distributionList = abi.decode(json, (DistributionList[]));
                console.log("Parsed distribution json");
                for (uint32 i = 0; i < distributionList.length; i++) {
                    (uint256 amount, bool success) = strToUint(distributionList[i].balance);
                    if (!success) {
                        console.log(
                            "Could not mint tokens for ", distributionList[i].recipient, "due to invalid balance"
                        );
                    } else {
                        mintTokensAndDelegate(distributionList[i].recipient, amount, distributionList[i].delegate);
                        console.log("Minted tokens", distributionList[i].balance);
                        console.log("Delegating to ", distributionList[i].delegate);
                    }
                }
            } catch {
                console.log("Could not parse distribution list");
            }
        }

        // deploy governor and vaults
        governor = address(new DualGovernor("SPOG Governor", vote, value, voteQuorum, valueQuorum, time));
        voteVault = address(new VoteVault(governor, auction));
        valueVault = address(new ValueVault(governor));

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

        spog = address(new SPOG(config));

        // transfer ownership of tokens to spog
        VoteToken(vote).transferOwnership(spog);
        ValueToken(value).transferOwnership(spog);

        SPOG(address(spog)).initialize();

        console.log("SPOG address: ", spog);
        console.log("SPOGVote token address: ", vote);
        console.log("SPOGValue token address: ", value);
        console.log("DualGovernor address: ", governor);
        console.log("Vote token vault address: ", voteVault);
        console.log("Value token vault address: ", valueVault);
        console.log("List Factory address: ", listFactory);
        if (cashDeployed) {
            console.log("Cash address: ", cash);
        }
    }
}
