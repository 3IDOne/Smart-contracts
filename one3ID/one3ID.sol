// SPDX-License-Identifier: MIT
// 3ID.one: Web3IDentity for everyOne
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract one3ID is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string private _baseTokenURI;

    struct Domain {
        uint256 id;
    }
    mapping(string => uint256) private _domainToTokenId;
    mapping(uint256 => string) private _tokenIdToDomain;
    mapping(string => uint256) private _extensionToFee;
    address private _feeRecipient;

    constructor(string memory baseURI, address initialOwner) ERC721("3ID.one", "3ID") Ownable(initialOwner) {
        _baseTokenURI = baseURI;
        _tokenIds.increment(); // Start token ID at 1
        _feeRecipient = initialOwner; // Set initial fee recipient to contract owner
    }

    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        for (uint256 i = 0; i < bStr.length; i++) {
            if (bStr[i] >= 0x41 && bStr[i] <= 0x5A) { // ASCII range for A-Z
                bStr[i] = bytes1(uint8(bStr[i]) + 32);
            }
        }
        return string(bStr);
    }

function _isAlphaNumeric(string memory str) internal pure returns (bool, string memory) {
    bytes memory b = bytes(str);
    uint8 dotCount = 0;
    uint256 firstDotIndex = 0;

    for (uint256 i = 0; i < b.length; i++) {
        bytes1 char = b[i];
        if (char == 0x2E) { // '.'
            dotCount++;
            if (dotCount == 1) {
                firstDotIndex = i;
            }
        } else if (!(char >= 0x30 && char <= 0x39) && // 0-9
                   !(char >= 0x61 && char <= 0x7A)) { // a-z
            return (false, "");
        }
    }

    if (dotCount != 2) {
        return (false, "");
    }

    // Extract the extension (SLD.TLD) manually
    bytes memory extensionBytes = new bytes(b.length - firstDotIndex - 1);
    for (uint256 i = firstDotIndex + 1; i < b.length; i++) {
        extensionBytes[i - firstDotIndex - 1] = b[i];
    }

    return (true, string(extensionBytes));
}

function mintSubdomain(address subDomainOwner, string memory subDomain) public payable returns (uint256) {
    string memory domain = _toLower(subDomain);
    require(_domainToTokenId[domain] == 0, "Sub-domain already registered");
    require(bytes(domain).length > 0, "Sub-domain cannot be empty");

    (bool isValid, string memory extension) = _isAlphaNumeric(domain);
    require(isValid, "Sub-domain contains unsupported characters or incorrect format");

    uint256 fee = _extensionToFee[extension];
    require(msg.value >= fee, "Insufficient fee");
    require(fee > 0, "Extension not supported");

    uint256 newItemId = _tokenIds.current();
    _domainToTokenId[domain] = newItemId;
    _tokenIdToDomain[newItemId] = domain;

    _mint(subDomainOwner, newItemId);
    _tokenIds.increment();

    // Refund excess payment
    if (msg.value > fee) {
        payable(msg.sender).transfer(msg.value - fee);
    }

    return newItemId;
}

    function setFee(string memory extension, uint256 fee) external onlyOwner {
        _extensionToFee[extension] = fee;
    }

    function getFee(string memory extension) external view returns (uint256) {
        return _extensionToFee[extension];
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid address");
        _feeRecipient = newRecipient;
    }

    function withdrawFees() external {
        require(msg.sender == _feeRecipient, "Not authorized");
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(_feeRecipient).transfer(balance);
    }

    function resolve(string memory subDomain) external view returns (address) {
        uint256 tokenId = _domainToTokenId[_toLower(subDomain)];
        if (tokenId == 0) {
            return address(0);
        }
        return ownerOf(tokenId);
    }

    function setBaseTokenURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseTokenURI, _tokenIdToDomain[tokenId]));
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIds.current() - 1;
    }
}