// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../../lib/forge-std/src/Test.sol";
import { CommonBase } from "../../../lib/forge-std/src/Base.sol";
import { StdCheats } from "../../../lib/forge-std/src/StdCheats.sol";
import { StdUtils } from "../../../lib/forge-std/src/StdUtils.sol";

import { IEmergencyGovernor } from "../../../src/interfaces/IEmergencyGovernor.sol";
import { IPowerToken } from "../../../src/interfaces/IPowerToken.sol";

import { HolderStore } from "../stores/HolderStore.sol";
import { ProposalStore } from "../stores/ProposalStore.sol";
import { TimestampStore } from "../stores/TimestampStore.sol";

import { TestUtils } from "../../utils/TestUtils.sol";

contract TTGHandler is CommonBase, StdCheats, StdUtils, TestUtils {
    IPowerToken internal _powerToken;

    IEmergencyGovernor internal _emergencyGovernor;

    HolderStore internal _holderStore;
    ProposalStore internal _proposalStore;
    TimestampStore internal _timestampStore;

    constructor(
        IEmergencyGovernor emergencyGovernor_,
        IPowerToken powerToken_,
        HolderStore holderStore_,
        ProposalStore proposalStore_,
        TimestampStore timestampStore_
    ) {
        _emergencyGovernor = emergencyGovernor_;
        _powerToken = powerToken_;
        _holderStore = holderStore_;
        _proposalStore = proposalStore_;
        _timestampStore = timestampStore_;
    }

    function _setCurrentBlockTimestamp() internal {
        _timestampStore.setCurrentTimestamp(block.timestamp);
    }

    modifier warpToNextEpoch() {
        _warpToNextEpoch();
        _setCurrentBlockTimestamp();
        _;
    }

    modifier warpToVoteEpoch() {
        if (_isTransferEpoch(_currentEpoch())) {
            console2.log("Warping to next vote epoch...");
            _warpToNextVoteEpoch();
            console2.log("Warped to vote epoch %s", _currentEpoch());
        }
        _setCurrentBlockTimestamp();
        _;
    }

    modifier warpToTransferEpoch() {
        if (_isVotingEpoch(_currentEpoch())) {
            console2.log("Warping to next transfer epoch...");
            _warpToNextTransferEpoch();
            console2.log("Warped to transfer epoch %s", _currentEpoch());
        }
        _setCurrentBlockTimestamp();
        _;
    }

    /* ============ Emergency Governor Proposals ============ */

    function emergencyGovernorAddToList(uint256 registrarListSeed_, uint256 powerHolderIndexSeed_) external {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        console2.log("POWER holder %s is proposing emergency vote to add himself to list...", powerHolder_);

        _proposalStore.emergencyGovernorAddToList(powerHolder_, registrarListSeed_);
        _setCurrentBlockTimestamp();
    }

    function emergencyGovernorRemoveFromList(
        uint256 registrarListSeed_,
        uint256 powerHolderIndexSeed_,
        uint256 powerHolderToRemoveIndexSeed_
    ) external {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        address powerHolderToRemove_ = _holderStore.getPowerHolder(powerHolderToRemoveIndexSeed_);

        console2.log(
            "POWER holder %s is proposing emergency vote to remove %s from list...",
            powerHolder_,
            powerHolderToRemove_
        );

        _proposalStore.emergencyGovernorRemoveFromList(powerHolder_, registrarListSeed_, powerHolderToRemove_);
        _setCurrentBlockTimestamp();
    }

    function emergencyGovernorRemoveFromAndAddToList(
        uint256 registrarListSeed_,
        uint256 powerHolderIndexSeed_,
        uint256 powerHolderToRemoveIndexSeed_,
        uint256 powerHolderToAddIndexSeed_
    ) external {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        address powerHolderToRemove_ = _holderStore.getPowerHolder(powerHolderToRemoveIndexSeed_);
        address powerHolderToAdd_ = _holderStore.getPowerHolder(powerHolderToAddIndexSeed_);

        console2.log(
            "POWER holder %s is proposing emergency vote to remove %s from list and add %s...",
            powerHolder_,
            powerHolderToRemove_,
            powerHolderToAdd_
        );

        _proposalStore.emergencyGovernorRemoveFromAndAddToList(
            powerHolder_,
            registrarListSeed_,
            powerHolderToRemove_,
            powerHolderToAdd_
        );

        _setCurrentBlockTimestamp();
    }

    function emergencyGovernorSetKey(uint256 powerHolderIndexSeed_, uint256 keySeed_, uint256 valueSeed_) external {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        console2.log("POWER holder %s is proposing emergency vote to set key value pair...", powerHolder_);

        _proposalStore.emergencyGovernorSetKey(powerHolder_, keySeed_, valueSeed_);
        _setCurrentBlockTimestamp();
    }

    function emergencyGovernorSetStandardProposalFee(uint256 powerHolderIndexSeed_, uint256 proposalFeeSeed_) external {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        console2.log(
            "POWER holder %s is proposing emergency vote to set Standard Governor proposal fee...",
            powerHolder_
        );

        _proposalStore.emergencyGovernorSetStandardProposalFee(powerHolder_, proposalFeeSeed_);
        _setCurrentBlockTimestamp();
    }

    /* ============ Standard Governor Proposals ============ */

    function standardGovernorAddToList(
        uint256 registrarListSeed_,
        uint256 powerHolderIndexSeed_
    ) external warpToTransferEpoch {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        console2.log("POWER holder %s is proposing standard vote to add himself to list...", powerHolder_);

        _proposalStore.standardGovernorAddToList(powerHolder_, registrarListSeed_);
        _setCurrentBlockTimestamp();
    }

    function standardGovernorRemoveFromList(
        uint256 registrarListSeed_,
        uint256 powerHolderIndexSeed_,
        uint256 powerHolderToRemoveIndexSeed_
    ) external warpToTransferEpoch {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        address powerHolderToRemove_ = _holderStore.getPowerHolder(powerHolderToRemoveIndexSeed_);

        console2.log(
            "POWER holder %s is proposing standard vote to remove %s from list...",
            powerHolder_,
            powerHolderToRemove_
        );

        _proposalStore.standardGovernorRemoveFromList(powerHolder_, registrarListSeed_, powerHolderToRemove_);
        _setCurrentBlockTimestamp();
    }

    function standardGovernorRemoveFromAndAddToList(
        uint256 registrarListSeed_,
        uint256 powerHolderIndexSeed_,
        uint256 powerHolderToRemoveIndexSeed_,
        uint256 powerHolderToAddIndexSeed_
    ) external warpToTransferEpoch {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        address powerHolderToRemove_ = _holderStore.getPowerHolder(powerHolderToRemoveIndexSeed_);
        address powerHolderToAdd_ = _holderStore.getPowerHolder(powerHolderToAddIndexSeed_);

        console2.log(
            "POWER holder %s is proposing standard vote to remove %s from list and add %s...",
            powerHolder_,
            powerHolderToRemove_,
            powerHolderToAdd_
        );

        _proposalStore.standardGovernorRemoveFromAndAddToList(
            powerHolder_,
            registrarListSeed_,
            powerHolderToRemove_,
            powerHolderToAdd_
        );

        _setCurrentBlockTimestamp();
    }

    function standardGovernorSetKey(
        uint256 powerHolderIndexSeed_,
        uint256 keySeed_,
        uint256 valueSeed_
    ) external warpToTransferEpoch {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        console2.log("POWER holder %s is proposing standard vote to set key value pair...", powerHolder_);

        _proposalStore.standardGovernorSetKey(powerHolder_, keySeed_, valueSeed_);
        _setCurrentBlockTimestamp();
    }

    function standardGovernorSetProposalFee(
        uint256 powerHolderIndexSeed_,
        uint256 proposalFeeSeed_
    ) external warpToTransferEpoch {
        address powerHolder_ = _holderStore.getPowerHolder(powerHolderIndexSeed_);
        console2.log("POWER holder %s is proposing standard vote to set proposal fee...", powerHolder_);

        _proposalStore.standardGovernorSetProposalFee(powerHolder_, proposalFeeSeed_);
        _setCurrentBlockTimestamp();
    }

    /* ============ Vote on proposal ============ */

    function voteOnEmergencyGovernorProposal(uint256 proposalIdSeed_, uint256 supportSeed_) external {
        _proposalStore.voteOnEmergencyGovernorProposal(proposalIdSeed_, supportSeed_, _holderStore.powerHolders());
        _setCurrentBlockTimestamp();
    }

    function voteOnStandardGovernorProposal(uint256 proposalIdSeed_, uint256 supportSeed_) external warpToVoteEpoch {
        _proposalStore.voteOnStandardGovernorProposal(proposalIdSeed_, supportSeed_, _holderStore.powerHolders());
        _setCurrentBlockTimestamp();
    }

    /* ============ Execute proposal ============ */

    function executeEmergencyGovernorProposal(uint256 proposalIdSeed_) external {
        _proposalStore.executeEmergencyGovernorProposal(proposalIdSeed_);
        _setCurrentBlockTimestamp();
    }

    function executeStandardGovernorProposal(uint256 proposalIdSeed_) external warpToTransferEpoch {
        _proposalStore.executeStandardGovernorProposal(proposalIdSeed_);
        _setCurrentBlockTimestamp();
    }
}
