// SPDX-License-Identifier: Revewz Organization

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract RevewzToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("Revewz", "RVZ");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _mint(msg.sender, 1000000 * 10**decimals());
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        
     
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function transferAdminRole(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, to);
        _grantRole(PAUSER_ROLE, to);
        _grantRole(MINTER_ROLE, to);
        _grantRole(UPGRADER_ROLE, to);
        _revokeRole(PAUSER_ROLE, msg.sender);
        _revokeRole(MINTER_ROLE, msg.sender);
        _revokeRole(UPGRADER_ROLE, msg.sender);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
