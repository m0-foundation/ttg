// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SPOGGovernorBase} from "src/core/governance/SPOGGovernorBase.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

abstract contract SPOGStorage is ISPOG {
    struct SPOGData {
        uint256 tax;
        uint256 inflator;
        uint256[2] taxRange;
        IERC20 cash;
    }

    SPOGData public spogData;
    uint256 public immutable valueFixedInflationAmount;

    // @note The vote governor can be changed by value governance with `RESET` proposal
    SPOGGovernorBase public voteGovernor;
    SPOGGovernorBase public immutable valueGovernor;

    modifier onlyVoteGovernor() {
        if (msg.sender != address(voteGovernor)) revert OnlyVoteGovernor();

        _;
    }

    modifier onlyValueGovernor() {
        if (msg.sender != address(valueGovernor)) revert OnlyValueGovernor();

        _;
    }

    constructor(
        bytes memory _initSPOGData,
        SPOGGovernorBase _voteGovernor,
        SPOGGovernorBase _valueGovernor,
        uint256 _time,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _valueFixedInflationAmount
    ) {
        initSPOGData(_initSPOGData);

        if (address(_voteGovernor) == address(_valueGovernor)) revert GovernorsShouldNotBeSame();

        if (address(_voteGovernor) == address(0) || address(_valueGovernor) == address(0)) revert ZeroAddress();

        if (_time == 0 || _voteQuorum == 0 || _valueQuorum == 0 || _valueFixedInflationAmount == 0) revert ZeroValues();

        voteGovernor = _voteGovernor;
        valueGovernor = _valueGovernor;

        valueFixedInflationAmount = _valueFixedInflationAmount;

        // set SPOG address in vote governor
        voteGovernor.initSPOGAddress(address(this));

        // set quorum and voting period for vote governor
        voteGovernor.updateQuorumNumerator(_voteQuorum);
        voteGovernor.updateVotingTime(_time);

        // set SPOG address in value governor
        valueGovernor.initSPOGAddress(address(this));

        // set quorum and voting period for value governor
        valueGovernor.updateQuorumNumerator(_valueQuorum);
        valueGovernor.updateVotingTime(_time);
    }

    /// @param _initSPOGData The data used to initialize spogData
    function initSPOGData(bytes memory _initSPOGData) internal {
        // _cash The currency accepted for tax payment in the SPOG (must be ERC20)
        // _taxRange The minimum and maximum value of `tax`
        // _inflator The percentage supply increase in $VOTE for each voting epoch
        // _reward The number of $VALUE to be distributed in each voting epoch
        // _tax The cost (in `cash`) to call various functions
        (address _cash, uint256[2] memory _taxRange, uint256 _inflator, uint256 _tax) =
            abi.decode(_initSPOGData, (address, uint256[2], uint256, uint256));

        if (_tax < _taxRange[0] || _tax > _taxRange[1]) revert InitTaxOutOfRange();
        if (_cash == address(0) || _inflator == 0) revert InitCashAndInflatorCannotBeZero();

        spogData = SPOGData({cash: IERC20(_cash), taxRange: _taxRange, inflator: _inflator, tax: _tax});
    }

    /// @dev Getter for taxRange. It returns the minimum and maximum value of `tax`
    /// @return The minimum and maximum value of `tax`
    function taxRange() external view override returns (uint256, uint256) {
        return (spogData.taxRange[0], spogData.taxRange[1]);
    }

    function changeTax(uint256 _tax) external onlyVoteGovernor {
        if (_tax < spogData.taxRange[0] || _tax > spogData.taxRange[1]) revert TaxOutOfRange();

        spogData.tax = _tax;

        emit TaxChanged(_tax);
    }

    /// @dev file double quorum function to change the following values: cash, taxRange, inflator, time, voteQuorum, and valueQuorum.
    /// @param what The value to be changed
    /// @param value The new value
    function change(bytes32 what, bytes calldata value) external override onlyVoteGovernor {
        bytes32 identifier = keccak256(abi.encodePacked(what, value));

        _changeWithDoubleQuorum(what, value);

        emit DoubleQuorumFinalized(identifier);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _changeWithDoubleQuorum(bytes32 what, bytes calldata value) private {
        if (what == "cash") {
            spogData.cash = abi.decode(value, (IERC20));
        } else if (what == "taxRange") {
            spogData.taxRange = abi.decode(value, (uint256[2]));
        } else if (what == "inflator") {
            spogData.inflator = abi.decode(value, (uint256));
        } else if (what == "time") {
            uint256 decodedTime = abi.decode(value, (uint256));
            voteGovernor.updateVotingTime(decodedTime);
            valueGovernor.updateVotingTime(decodedTime);
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
