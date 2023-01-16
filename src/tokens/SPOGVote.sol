// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.14;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../interfaces/ISPOGVote.sol";

/// @title SPOGVote: token used to vote on a SPOG
contract SPOGVote is
    ERC20,
    Votes,
    ERC20Burnable,
    AccessControlEnumerable,
    ISPOGVote
{
    bytes32 public constant SPOG = keccak256("SPOG");

    /// @dev A mapping of frozen accounts
    mapping(address => bool) public isAccountFrozen;

    /// @dev Initializes the contract by creating the token as well as the default admin role and the SPOG role
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(SPOG, _msgSender()); // TODO: should be revised to add a SPOG contract as the SPOG role
    }

    /// @dev Restricts minting to the SPOG. Cannot mint more than the max cap
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public override onlyRole(SPOG) {
        require(totalSupply() + amount <= MAX_CAP, "WTR: cap exceeded");
        _mint(to, amount);
    }

    /// @dev override totalSupply to return the total supply of the token in the voting contract
    function totalSupply() public view override returns (uint256) {
        return _getTotalSupply();
    }
}
