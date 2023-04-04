// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

abstract contract SPOGStorage is ISPOG {
    struct SPOGData {
        uint256 tax;
        uint256 inflatorTime;
        uint256 sellTime;
        uint256 forkTime;
        uint256 inflator;
        uint256 reward;
        uint256[2] taxRange;
        IERC20 cash;
    }

    SPOGData public spogData;

    ISPOGGovernor public immutable voteGovernor;
    ISPOGGovernor public immutable valueGovernor;

    // TODO: variable packing for SPOGData: https://dev.to/javier123454321/solidity-gas-optimizations-pt-3-packing-structs-23f4

    constructor(
        ISPOGGovernor _voteGovernor,
        ISPOGGovernor _valueGovernor,
        uint256 _voteTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum
    ) {
        voteGovernor = _voteGovernor;
        valueGovernor = _valueGovernor;

        // Set SPOG address in vote governor
        voteGovernor.initSPOGAddress(address(this));

        // set quorum and voting period for vote governor
        voteGovernor.updateQuorumNumerator(_voteQuorum);
        voteGovernor.updateVotingTime(_voteTime);

        // Set SPOG address in value governor
        valueGovernor.initSPOGAddress(address(this));

        // set quorum and voting period for value governor
        valueGovernor.updateQuorumNumerator(_valueQuorum);
        valueGovernor.updateVotingTime(_voteTime);
    }

    modifier onlyVoteGovernor() {
        require(msg.sender == address(voteGovernor), "SPOG: Only vote governor");

        _;
    }

    /// @dev Getter for taxRange. It returns the minimum and maximum value of `tax`
    /// @return The minimum and maximum value of `tax`
    function taxRange() external view returns (uint256, uint256) {
        return (spogData.taxRange[0], spogData.taxRange[1]);
    }

    function changeTax(uint256 _tax) external onlyVoteGovernor {
        require(_tax >= spogData.taxRange[0] && _tax <= spogData.taxRange[1], "SPOG: Tax out of range");

        spogData.tax = _tax;

        emit TaxChanged(_tax);
    }

    /// @dev file double quorum function to change the following values: cash, taxRange, inflator, reward, voteTime, inflatorTime, sellTime, forkTime, voteQuorum, and valueQuorum.
    /// @param what The value to be changed
    /// @param value The new value
    function change(bytes32 what, bytes calldata value) external onlyVoteGovernor {
        bytes32 identifier = keccak256(abi.encodePacked(what, value));

        _fileWithDoubleQuorum(what, value);

        emit DoubleQuorumFinalized(identifier);
    }

    /**
     * Private Function ***
     */

    function _fileWithDoubleQuorum(bytes32 what, bytes calldata value) private {
        if (what == "cash") {
            spogData.cash = abi.decode(value, (IERC20));
        } else if (what == "taxRange") {
            spogData.taxRange = abi.decode(value, (uint256[2]));
        } else if (what == "inflator") {
            spogData.inflator = abi.decode(value, (uint256));
        } else if (what == "reward") {
            spogData.reward = abi.decode(value, (uint256));
        } else if (what == "inflatorTime") {
            spogData.inflatorTime = abi.decode(value, (uint256));
        } else if (what == "sellTime") {
            spogData.sellTime = abi.decode(value, (uint256));
        } else if (what == "forkTime") {
            spogData.forkTime = abi.decode(value, (uint256));
        } else if (what == "voteTime") {
            uint256 decodedVoteTime = abi.decode(value, (uint256));
            voteGovernor.updateVotingTime(decodedVoteTime);
            valueGovernor.updateVotingTime(decodedVoteTime);
        } else if (what == "voteQuorum") {
            uint256 decodedVoteQuorum = abi.decode(value, (uint256));
            voteGovernor.updateQuorumNumerator(decodedVoteQuorum);
        } else if (what == "valueQuorum") {
            uint256 decodedValueQuorum = abi.decode(value, (uint256));
            valueGovernor.updateQuorumNumerator(decodedValueQuorum);
        } else {
            revert InvalidParameter(what);
        }
    }
}
