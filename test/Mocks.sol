// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

contract MockEpochBasedVoteToken {
    mapping(uint256 epoch => uint256 totalSupply) internal _totalSupplyAt;

    function setTotalSupplyAt(uint256 epoch_, uint256 totalSupplyAt_) external {
        _totalSupplyAt[epoch_] = totalSupplyAt_;
    }

    function totalSupplyAt(uint256 epoch_) external view returns (uint256 totalSupply_) {
        totalSupply_ = _totalSupplyAt[epoch_];
    }
}
