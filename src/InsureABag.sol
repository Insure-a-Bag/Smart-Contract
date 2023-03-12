// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import { ERC5643 } from "src/ERC5643.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { Pausable } from "openzeppelin-contracts/contracts/security/Pausable.sol";

contract InsureABag is ERC5643, Ownable, Pausable {
    error TokenAlreadyInsured();

    error IsZeroAddress();

    /*//////////////////////////////////////////////////////////////
                             LIB IMPORTS
    //////////////////////////////////////////////////////////////*/

    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NonexistentToken();

    /*//////////////////////////////////////////////////////////////
                                 ENUM
    //////////////////////////////////////////////////////////////*/

    enum ExpiryDuration {
        Year,
        TwoYears,
        ThreeYears
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCT
    //////////////////////////////////////////////////////////////*/

    struct PolicyInfo {
        uint256 insuredTokenId;
        uint256 expiresTimestamp;
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VARS
    //////////////////////////////////////////////////////////////*/

    uint256 private currentIndex;

    address public vaultAddress;

    string public baseURI;

    string public URIExtension;

    bytes32 public collectionsMerkleRoot;

    mapping(address => mapping(address => PolicyInfo)) internal _currentUsers;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_) ERC5643(name_, symbol_) { }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getCurrentBlockstamp() internal view returns (uint256) {
        return block.timestamp;
    }

    function getExpiryTimestamp(ExpiryDuration _expiryDuration) internal view returns (uint256) {
        uint256 expiresTimestamp;
        if (_expiryDuration == ExpiryDuration.Year) {
            expiresTimestamp = getCurrentBlockstamp() + 365 days;
        } else if (_expiryDuration == ExpiryDuration.TwoYears) {
            expiresTimestamp = getCurrentBlockstamp() + 730 days;
        } else if (_expiryDuration == ExpiryDuration.ThreeYears) {
            expiresTimestamp = getCurrentBlockstamp() + 1460 days;
        }
        return expiresTimestamp;
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setVaultAddress(address _vaultAddress) external onlyOwner {
        if (_vaultAddress == address(0)) revert IsZeroAddress();
        vaultAddress = _vaultAddress;
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setURIExtension(string memory _uriExtension) external onlyOwner {
        URIExtension = _uriExtension;
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                        URI FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) revert NonexistentToken();
        return string(abi.encodePacked(baseURI, _tokenId.toString(), URIExtension));
    }

    /*//////////////////////////////////////////////////////////////
                        MINT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Need to add price logic and whitelisted collections only

    function mintInsurancePolicy(
        address _collectionAddress,
        uint256 _insuredToken,
        ExpiryDuration _expiryDuration
    )
        external
        payable
    {
        if (_currentUsers[msg.sender][_collectionAddress].insuredTokenId == _insuredToken) {
            revert TokenAlreadyInsured();
        }
        PolicyInfo memory newPolicy =
            PolicyInfo({ insuredTokenId: _insuredToken, expiresTimestamp: getExpiryTimestamp(_expiryDuration) });
        _currentUsers[msg.sender][_collectionAddress] = newPolicy;
        currentIndex += 1;
        _safeMint(msg.sender, currentIndex);
    }
}
