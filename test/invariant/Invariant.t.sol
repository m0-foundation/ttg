// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;
import { console2 } from "../../lib/forge-std/src/Test.sol";
import { DeployBase } from "../../script/DeployBase.sol";

import { IEmergencyGovernorDeployer } from "../../src/interfaces/IEmergencyGovernorDeployer.sol";
import { IStandardGovernorDeployer } from "../../src/interfaces/IStandardGovernorDeployer.sol";

import { IEmergencyGovernor } from "../../src/interfaces/IEmergencyGovernor.sol";
import { IPowerToken } from "../../src/interfaces/IPowerToken.sol";
import { IRegistrar } from "../../src/interfaces/IRegistrar.sol";
import { IStandardGovernor } from "../../src/interfaces/IStandardGovernor.sol";
import { IZeroGovernor } from "../../src/interfaces/IZeroGovernor.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";
import { IDistributionVault } from "../../src/interfaces/IDistributionVault.sol";

import { ERC20ExtendedHarness } from "../utils/ERC20ExtendedHarness.sol";
import { TestUtils } from "../utils/TestUtils.sol";

import { TTGHandler } from "./handlers/TTGHandler.sol";

import { HolderStore } from "./stores/HolderStore.sol";
import { ProposalStore } from "./stores/ProposalStore.sol";
import { TimestampStore } from "./stores/TimestampStore.sol";

contract InvariantTests is TestUtils {
    TTGHandler internal _handler;

    HolderStore internal _holderStore;
    ProposalStore internal _proposalStore;
    TimestampStore internal _timestampStore;

    IRegistrar internal _registrar;

    IPowerToken internal _powerToken;
    IZeroToken internal _zeroToken;

    IEmergencyGovernor internal _emergencyGovernor;
    IStandardGovernor internal _standardGovernor;
    IZeroGovernor internal _zeroGovernor;

    IDistributionVault internal _vault;

    ERC20ExtendedHarness internal _cashToken1 = new ERC20ExtendedHarness("Cash Token 1", "CASH1", 18);
    ERC20ExtendedHarness internal _cashToken2 = new ERC20ExtendedHarness("Cash Token 1", "CASH2", 6);

    address[] internal _allowedCashTokens = [address(_cashToken1), address(_cashToken2)];

    uint256 internal _standardProposalFee = 1e18;

    DeployBase internal _deploy;

    modifier useCurrentTimestamp() {
        vm.warp(_timestampStore.currentTimestamp());
        _;
    }

    function setUp() external {
        _deploy = new DeployBase();
        _holderStore = new HolderStore();
        _timestampStore = new TimestampStore();

        _holderStore.initActors();

        address[][2] memory initialAccounts_ = [_holderStore.powerHolders(), _holderStore.zeroHolders()];
        uint256[][2] memory initialBalances_ = [_holderStore.powerHolderBalances(), _holderStore.zeroHolderBalances()];

        // NOTE: Using `DeployBase` as a contract instead of a script, means that the deployer is `_deploy` itself.
        address registrar_ = _deploy.deploy(
            address(_deploy),
            1,
            initialAccounts_,
            initialBalances_,
            _standardProposalFee,
            _allowedCashTokens
        );

        _registrar = IRegistrar(registrar_);

        _powerToken = IPowerToken(_registrar.powerToken());
        _zeroToken = IZeroToken(_registrar.zeroToken());

        _emergencyGovernor = IEmergencyGovernor(_registrar.emergencyGovernor());
        _standardGovernor = IStandardGovernor(_registrar.standardGovernor());
        _zeroGovernor = IZeroGovernor(_registrar.zeroGovernor());

        _proposalStore = new ProposalStore(
            _registrar,
            _emergencyGovernor,
            _standardGovernor,
            _zeroGovernor,
            _allowedCashTokens,
            _holderStore
        );

        _vault = IDistributionVault(_standardGovernor.vault());

        _handler = new TTGHandler(_emergencyGovernor, _powerToken, _holderStore, _proposalStore, _timestampStore);

        // Set fuzzer to only call the handler
        targetContract(address(_handler));

        bytes4[] memory selectors = new bytes4[](21);
        selectors[0] = TTGHandler.emergencyGovernorAddToList.selector;
        selectors[1] = TTGHandler.emergencyGovernorRemoveFromList.selector;
        selectors[2] = TTGHandler.emergencyGovernorRemoveFromAndAddToList.selector;
        selectors[3] = TTGHandler.emergencyGovernorSetKey.selector;
        selectors[4] = TTGHandler.emergencyGovernorSetStandardProposalFee.selector;
        selectors[5] = TTGHandler.voteOnEmergencyGovernorProposal.selector;
        selectors[6] = TTGHandler.executeEmergencyGovernorProposal.selector;
        selectors[7] = TTGHandler.standardGovernorAddToList.selector;
        selectors[8] = TTGHandler.standardGovernorRemoveFromList.selector;
        selectors[9] = TTGHandler.standardGovernorRemoveFromAndAddToList.selector;
        selectors[10] = TTGHandler.standardGovernorSetKey.selector;
        selectors[11] = TTGHandler.standardGovernorSetProposalFee.selector;
        selectors[12] = TTGHandler.voteOnAllStandardGovernorProposals.selector;
        selectors[13] = TTGHandler.executeAllStandardGovernorProposals.selector;
        selectors[14] = TTGHandler.zeroGovernorResetToPowerHolders.selector;
        selectors[15] = TTGHandler.zeroGovernorResetToZeroHolders.selector;
        selectors[16] = TTGHandler.zeroGovernorSetCashToken.selector;
        selectors[17] = TTGHandler.zeroGovernorSetEmergencyProposalThresholdRatio.selector;
        selectors[18] = TTGHandler.zeroGovernorSetZeroProposalThresholdRatio.selector;
        selectors[19] = TTGHandler.voteOnZeroGovernorProposal.selector;
        selectors[20] = TTGHandler.executeZeroGovernorProposal.selector;

        targetSelector(FuzzSelector({ addr: address(_handler), selectors: selectors }));

        // Prevent these contracts from being fuzzed as `msg.sender`.
        excludeSender(address(_deploy));
        excludeSender(address(_handler));
        excludeSender(address(_proposalStore));
        excludeSender(address(_holderStore));
        excludeSender(address(_timestampStore));
        excludeSender(address(_cashToken1));
        excludeSender(address(_cashToken2));
        excludeSender(address(_powerToken));
        excludeSender(address(_zeroToken));
        excludeSender(address(_emergencyGovernor));
        excludeSender(address(_standardGovernor));
        excludeSender(address(_zeroGovernor));
        excludeSender(address(_registrar));
        excludeSender(address(_vault));

        // Warp to the next epoch to init ZERO balances
        _warpToNextEpoch();
    }

    function invariant_main() public useCurrentTimestamp {
        vm.skip(true);
        console2.log(
            "Checking invariants for epoch %s at timestamp %s...",
            _currentEpoch(),
            _timestampStore.currentTimestamp()
        );

        IPowerToken nextPowerToken_ = _proposalStore.nextPowerToken();

        // If a reset has occured, update contracts addresses with new addresses
        if (address(nextPowerToken_) != address(0)) {
            _powerToken = nextPowerToken_;

            _emergencyGovernor = IEmergencyGovernor(
                IEmergencyGovernorDeployer(_registrar.emergencyGovernorDeployer()).lastDeploy()
            );

            _standardGovernor = IStandardGovernor(
                IStandardGovernorDeployer(_registrar.standardGovernorDeployer()).lastDeploy()
            );
        }

        uint256 totalSupply_;
        uint256 totalVotes_;

        for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
            totalSupply_ += _powerToken.balanceOf(_holderStore.powerHolders()[i]);
        }

        for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
            totalVotes_ += _powerToken.getVotes(_holderStore.powerHolders()[i]);
        }

        // Skip test if POWER total supply and/or voting power are zero.
        vm.assume(totalVotes_ != 0);
        vm.assume(_powerToken.totalSupply() != 0);

        if (_proposalStore.hasVotedOnAllStandardProposals()) {
            // Inflation is only realized in the next transfer epoch, so we warp to the next epoch to check
            if (!_isTransferEpoch(_currentEpoch())) {
                console2.log("Warping to next epoch to realize inflation...");
                _warpToNextEpoch();
                console2.log("Warped to next epoch: %s", _currentEpoch());
            }
        }

        assertGe(
            _powerToken.totalSupply(),
            totalSupply_,
            "POWER token totalSupply() should be greater than or equal to the sum of POWER token balanceOf()"
        );

        assertGe(
            _powerToken.totalSupply(),
            totalVotes_,
            "POWER token totalSupply() should be greater than or equal to the sum of POWER token getVotes()"
        );

        assertGe(
            totalVotes_,
            totalSupply_,
            "The sum of POWER token getVotes() should be greater than or equal to the sum of POWER token balanceOf()"
        );

        if (address(nextPowerToken_) != address(0)) {
            uint16 bootstrapEpoch_ = _powerToken.bootstrapEpoch();

            if (_proposalStore.hasExecutedResetToPowerHolders()) {
                for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
                    address powerHolder_ = _holderStore.powerHolders()[i];

                    // If inflation has been realized after reset, check expected voting power
                    if (_proposalStore.hasVotedOnAllStandardProposals()) {
                        assertEq(
                            _powerToken.balanceOf(powerHolder_),
                            _proposalStore.nextVotingPower(powerHolder_),
                            "POWER token balance for initial POWER holders should be equal to the balance at bootstrap epoch + any inflation"
                        );

                        assertEq(
                            _powerToken.getVotes(powerHolder_),
                            _proposalStore.nextVotingPower(powerHolder_),
                            "POWER token votes for initial POWER holders should be equal to the votes at bootstrap epoch + any inflation"
                        );
                    } else {
                        assertEq(
                            _powerToken.balanceOf(powerHolder_),
                            _powerToken.pastBalanceOf(powerHolder_, bootstrapEpoch_),
                            "POWER token balance for initial POWER holders should be equal to the balance at bootstrap epoch"
                        );

                        assertEq(
                            _powerToken.getVotes(powerHolder_),
                            _powerToken.getPastVotes(powerHolder_, bootstrapEpoch_),
                            "POWER token votes for initial POWER holders should be equal to the votes at bootstrap epoch"
                        );
                    }
                }

                for (uint256 i; i < _holderStore.ZERO_HOLDER_NUM(); i++) {
                    address zeroHolder_ = _holderStore.zeroHolders()[i];

                    assertEq(
                        _powerToken.balanceOf(zeroHolder_),
                        _powerToken.pastBalanceOf(zeroHolder_, bootstrapEpoch_),
                        "POWER token balance for initial ZERO holders should be equal to the balance at bootstrap epoch"
                    );

                    assertEq(
                        _powerToken.getVotes(zeroHolder_),
                        _powerToken.getPastVotes(zeroHolder_, bootstrapEpoch_),
                        "POWER token votes for initial ZERO holders should be equal to the votes at bootstrap epoch"
                    );
                }

                // Set to false now that the reset has been executed and balances checked
                _proposalStore.setHasExecutedResetToPowerHolders(false);
            }

            if (_proposalStore.hasExecutedResetToZeroHolders()) {
                address[] memory prevPowerHolders_ = _holderStore.zeroHolders();
                address[] memory prevZeroHolders_ = _holderStore.powerHolders();

                address initialPowerHolder_;

                for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
                    initialPowerHolder_ = prevPowerHolders_[i];

                    uint240 zeroRewards_ = _proposalStore.zeroRewards(initialPowerHolder_);
                    uint240 bootstrapBalance_ = zeroRewards_ != 0
                        ? _getBootstrapBalance(
                            initialPowerHolder_,
                            address(_zeroToken),
                            bootstrapEpoch_,
                            _powerToken.INITIAL_SUPPLY(),
                            _currentEpoch()
                        )
                        : 0;

                    assertEq(
                        _powerToken.balanceOf(initialPowerHolder_),
                        bootstrapBalance_,
                        "POWER token balance for initial POWER holders should be equal to the bootstrap balance"
                    );

                    assertEq(
                        _powerToken.getVotes(initialPowerHolder_),
                        bootstrapBalance_,
                        "POWER token votes for initial POWER holders should be equal to the bootstrap balance"
                    );

                    // Reset ZERO rewards now that balances have been checked
                    _proposalStore.setZeroRewards(initialPowerHolder_, 0);
                }

                address initialZeroholder_;

                for (uint256 i; i < _holderStore.ZERO_HOLDER_NUM(); i++) {
                    initialZeroholder_ = prevZeroHolders_[i];
                    initialPowerHolder_ = prevPowerHolders_[i];

                    // If inflation has been realized after reset, check expected voting power
                    if (_proposalStore.hasVotedOnAllStandardProposals()) {
                        assertEq(
                            _powerToken.balanceOf(initialZeroholder_),
                            _proposalStore.nextVotingPower(initialZeroholder_),
                            "POWER token balance for initial ZERO holders should be equal to the balance at bootstrap epoch + any inflation realized"
                        );

                        assertEq(
                            _powerToken.getVotes(initialZeroholder_),
                            _proposalStore.nextVotingPower(initialZeroholder_),
                            "POWER token votes for initial ZERO holders should be equal to the balance at bootstrap epoch + any inflation realized"
                        );
                    } else {
                        assertEq(
                            _powerToken.balanceOf(initialZeroholder_),
                            _powerToken.pastBalanceOf(initialZeroholder_, bootstrapEpoch_),
                            "POWER token balance for initial ZERO holders should be equal to the balance at bootstrap epoch"
                        );

                        assertEq(
                            _powerToken.getVotes(initialZeroholder_),
                            _powerToken.getPastVotes(initialZeroholder_, bootstrapEpoch_),
                            "POWER token votes for initial ZERO holders should be equal to the balance at bootstrap epoch"
                        );
                    }

                    // Reset next voting power now that balances have been checked
                    _proposalStore.setNextVotingPower(initialZeroholder_, 0);
                }

                // Reset state now that the reset has been executed and balances checked
                _proposalStore.setHasExecutedResetToZeroHolders(false);
                _proposalStore.setNextPowerToken(address(0));
            }
        }

        if (_proposalStore.hasVotedOnAllStandardProposals()) {
            if (_proposalStore.nextPowerTargetEpoch() + 1 == _currentEpoch()) {
                uint256 nextTotalVotes_;

                for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
                    nextTotalVotes_ += _powerToken.getVotes(_holderStore.powerHolders()[i]);
                }

                assertEq(
                    nextTotalVotes_,
                    _proposalStore.nextPowerTargetVotes(),
                    "POWER token total votes should account for inflation and equal the target votes"
                );

                assertEq(
                    _powerToken.totalSupply() + _powerToken.amountToAuction(),
                    _proposalStore.nextPowerTargetSupply(),
                    "POWER token totalSupply() should account for inflation and equal the target supply"
                );

                assertEq(
                    _zeroToken.totalSupply(),
                    _proposalStore.nextZeroTargetSupply(),
                    "ZERO token totalSupply() should account for inflation and equal the target supply"
                );

                // Reset state now that the inflation has been checked
                _proposalStore.setNextPowerTargetEpoch(0);
                _proposalStore.setHasVotedOnAllStandardProposals(false);
            }
        }
    }
}
