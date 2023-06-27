// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "./SPOGVotes.sol";
import "src/interfaces/ISPOG.sol";

contract InflationaryVotes is SPOGInflationaryVotes {
    // owner => count of epochs delegate already voted on at the start of delegation
    mapping(address => uint256) private _delegateActivityStart;
    mapping(address => uint256) private _rewards;

    constructor(string memory name, string memory symbol) SPOGInflationaryVotes(name, symbol) {}

    function _delegate(address delegator, address delegatee) internal virtual override {
        // cash out your rewards
        _accrueRewards(delegator);
        _startNewDelegationCycle(delegator, delegatee);

        super._delegate(delegator, delegatee);
    }

    function _accrueRewards(address delegator) internal virtual {
        address currentDelegate = delegates(delegator);
        uint256 delegatorBalance = balanceOf(delegator);

        // calculate rewards for num of active epochs (delegate voted on all proposals in these epochs)
        uint256 delegateActiveEpochs = ISPOG(spog).governor().numActiveEpochs(currentDelegate);
        uint256 delta = delegateActiveEpochs - _delegateActivityStart[currentDelegate];
        uint256 balanceWithReward = _compound(delegatorBalance, ISPOG(spog).inflator(), delta);
        uint256 reward = balanceWithReward - delegatorBalance;

        super._mint(delegator, reward);
        // Voting power of currentDelegate was already updated when vote was casted, no need for double upgrade
        _burnVotingPower(currentDelegate, reward);
    }

    function _startNewDelegationCycle(address delegator, address delegatee) internal virtual {
        _delegateActivityStart[delegator] = ISPOG(spog).governor().numActiveEpochs(delegatee);

        // TODO emit event here
    }

    // function _beforeTokenTransfer(address from, address to, uint256) internal virtual override {
    //     _accrueRewards(from);
    //     _startNewDelegationCycle(from, delegates(from));

    //     _accrueRewards(to);
    //     _startNewDelegationCycle(to, delegates(to));
    // }

    function mintVotingPowerReward(address account, uint256 amount) external {
        require(msg.sender == address(ISPOG(spog).governor()), "Caller is not governor");
        _mintVotingPower(account, amount);
    }

    // TODO: primitive implementation for demonstartion purposes only
    function _compound(uint256 principal, uint256 inflator, uint256 epochs) private pure returns (uint256) {
        for (uint256 i; i < epochs;) {
            principal += principal * inflator / 100;
            unchecked {
                ++i;
            }
        }
        return principal;
    }
}
