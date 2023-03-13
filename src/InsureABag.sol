// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import { ERC5643 } from "src/ERC5643.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { Pausable } from "openzeppelin-contracts/contracts/security/Pausable.sol";

contract InsureABag is ERC5643, Ownable, Pausable {
    /*//////////////////////////////////////////////////////////////
                             LIB IMPORTS
    //////////////////////////////////////////////////////////////*/

    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NonexistentToken();

    error TokenAlreadyInsured();

    error IsZeroAddress();

    error UnsupportedCollection();

    error InvalidDuration();

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

    function getDuration(uint256 _duration) internal pure returns (uint256) {
        if (_duration > 3) revert InvalidDuration();
        uint256 insuranceDuration;
        if (_duration == 1) {
            insuranceDuration = 365 days;
        } else if (_duration == 2) {
            insuranceDuration = 730 days;
        } else if (_duration == 3) {
            insuranceDuration = 1460 days;
        }
        return insuranceDuration;
    }

    /*//////////////////////////////////////////////////////////////
                        MERKLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setCollectionsMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        collectionsMerkleRoot = _merkleRoot;
    }

    function leaf(address _contractAddress) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_contractAddress));
    }

    function _verifyAddress(bytes32 _leaf, bytes32[] memory _proof) internal view returns (bool) {
        return MerkleProof.verify(_proof, collectionsMerkleRoot, _leaf);
    }

    function isCollectionAddressSupported(
        address _contractAddress,
        bytes32[] calldata _proof
    )
        internal
        view
        returns (bool)
    {
        return _verifyAddress(leaf(_contractAddress), _proof);
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

    //Need to add price logic
    function mintInsurancePolicy(
        address _contractAddress,
        uint256 _tokenId,
        bytes32[] calldata _proof,
        uint256 _duration
    )
        external
        payable
    {
        if (!isCollectionAddressSupported(_contractAddress, _proof)) revert UnsupportedCollection();
        if (_currentUsers[msg.sender][_contractAddress].insuredTokenId == _tokenId) revert TokenAlreadyInsured();

        PolicyInfo memory newPolicy =
            PolicyInfo({ insuredTokenId: _tokenId, expiresTimestamp: getCurrentBlockstamp() + getDuration(_duration) });
        _currentUsers[msg.sender][_contractAddress] = newPolicy;
        currentIndex += 1;
        _safeMint(msg.sender, currentIndex);
    }
}
