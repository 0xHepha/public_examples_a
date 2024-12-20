// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Imports

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ValeaTreasuresNFTExtra.sol";

// Defined errors

error vlaNFT__InsufficientFunds();
error vlaNFT__TransferFailed();
error vlaNFT__MintPaused();
error vlaNFT__InsufficientRemainingSupply(uint256);
error vlaNFT__InsufficentWLTokenAmount(uint256);
error vlaNFT__InsufficientContractBalance();
error vlaNFT__IvalidTokenID();

contract ValeaTreasuresNFT is ERC721Enumerable, ValeaTreasuresNFTExtra {
    //////////////////////////
    //      INTERFACES      //
    //////////////////////////

    /**
     * @dev Checks if the contract supports a specific interface via ERC165.
     * @param interfaceID The ID of the interface to check for.
     * @return True if the contract supports the interface, false otherwise.
     */
    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == 0x7f5828d0 || //0x7f5828d0 //173 Owner
            interfaceID == 0x2a55205a || //0x2a55205a //2918 Royalty
            super.supportsInterface(interfaceID);
    }

    ///////////////////////////////////////////////
    //      ValeaTreasuresNFT CONTRACT          //
    //////////////////////////////////////////////

    // Using OpenZeppelin's Strings library for uint256
    using Strings for uint256;

    // The total actual supply of tokens
    uint256 private _supply = 0;

    // The maximum supply of tokens. This will be changed for each phase
    uint256 private _maxSupply = 1000;

    // Indicates whether minting of tokens is paused
    bool private _isPaused = true;

    // The price to mint a new token
    uint256 private _mintPrice = 0.001 ether;

    // The URIs for different types of tokens
    string private _tokenURI = "https://testing-valea.netlify.app/api/tokenURI";

    // The URI of the contract
    // Contains info about the collection
    string private _contractURI = "https://testing-valea.netlify.app/api/contractURI";

    // Array of seeds that determinates the types of the tokens
    // Randomly generated using CHAINLINK at the POLYGON network contract: <UPTDATE ONCE DEPLOYED>
    // By calling getSeeds(1)
    // This ensures a full transparency on random generation(Right now the oracle world on zkSync is still early)

    mapping(uint256 => string) private _seeds;
    uint256 private _seedsCount = 0;

    // Indicates whether the whitelist is active
    bool private _isWhiteListActive = true;

    // Mapping from an address to the amount of tokens the address can mint in the WhiteList phase
    mapping(address => uint256) private _whiteList;

    /**
     * @dev The constructor sets the owner and the URIs for the different types of tokens.
     */
    constructor() ERC721("Valeas Mysterious Treasures", "vlaNFT") {
        _owner = msg.sender;
    }

    /**
     * @dev Toggles the whitelist active state. Only callable by the owner.
     */
    function enableDisableWhiteList() external onlyOwner {
        _isWhiteListActive = !_isWhiteListActive;
    }

    /**
     * @dev Adds addresses to the whitelist. Only callable by the owner.
     * @param newAddresses The addresses to add to the whitelist.
     * @param amount The amount of tokens each address is allowed to mint.
     * set amount to 0 to remove a user from whitelist
     */
    function addToWhiteList(address[] calldata newAddresses, uint256 amount) external onlyOwner {
        for (uint256 i = 0; i < newAddresses.length; i++) {
            _whiteList[newAddresses[i]] = amount;
        }
    }

    /**
     * @dev Returns the amount of tokens an address is allowed to mint.
     * @param userAddress The address to check.
     * @return The amount of tokens the address is allowed to mint.
     */
    function allowedToMint(address userAddress) external view returns (uint256) {
        return _whiteList[userAddress];
    }

    /**
     * @dev Withdraws funds from the contract. Only callable by the owner.
     * @param amount The amount of funds to withdraw specified in WEI
     */
    function withdrawFunds(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) revert vlaNFT__InsufficientContractBalance();

        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (!success) revert vlaNFT__TransferFailed();
    }

    /**
     * @dev Mints new tokens.
     * @param amount The amount of tokens to mint.
     * The value sent needs to be : mintPrice * amount
     */
    function mint(uint256 amount) external payable {
        if (_isPaused) revert vlaNFT__MintPaused();

        uint256 remaining = _maxSupply - _supply;

        if (amount > remaining) revert vlaNFT__InsufficientRemainingSupply(remaining);

        if (_isWhiteListActive) {
            if (amount > _whiteList[msg.sender])
                revert vlaNFT__InsufficentWLTokenAmount(_whiteList[msg.sender]);
        }

        uint256 requiredPayment = _mintPrice * amount;
        if (msg.value < requiredPayment) revert vlaNFT__InsufficientFunds();

        uint256 newSupply = _supply + amount;
        for (uint256 i = _supply + 1; i <= newSupply; i++) {
            _safeMint(msg.sender, i);
        }
        _supply = newSupply;
        if (_isWhiteListActive) {
            _whiteList[msg.sender] -= amount;
        }
    }

    /**
     * @dev Claims tokens for the owners and previous partners of the project
     * @param amount The amount of tokens to claim.
     * @param to The address to send the claimed tokens to.
     */
    function claim(uint256 amount, address to) external onlyOwner {
        uint256 remaining = _maxSupply - _supply;
        if (amount > remaining) revert vlaNFT__InsufficientRemainingSupply(remaining);

        for (uint256 i = 0; i < amount; i++) {
            _supply++;
            _safeMint(to, _supply);
        }
    }

    /**
     * @dev Returns the URI for a given token ID.
     * @param id The token ID.
     * @return The URI of the token.
     */
    function tokenURI(uint256 id) public view override returns (string memory) {
        if (id > _supply) revert vlaNFT__IvalidTokenID();

        if (_seedsCount > 0) {
            return string(abi.encodePacked(_tokenURI, "/", getBoxType(id).toString()));
        } else {
            return string(abi.encodePacked(_tokenURI, "/0"));
        }
    }

    /**
     * @dev Returns the tokens owned by a given address.
     * @param tokensOwner The address to check.
     * @return The token IDs owned by the address.
     */
    function tokensOfOwner(address tokensOwner) external view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(tokensOwner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);

        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(tokensOwner, i);
        }

        return tokenIds;
    }

    //////////// ADMIN SETTERS

    /**
     * @dev Toggles the pause state of the contract. Only callable by the owner.
     */
    function changePause() external onlyOwner {
        _isPaused = !_isPaused;
    }

    /**
     * @dev Sets the maximum supply of tokens. Only callable by the owner.
     * @param maxSupply The new maximum supply.
     */
    function setMaxSupply(uint256 maxSupply) external onlyOwner {
        _maxSupply = maxSupply;
    }

    /**
     * @dev Sets the mint price for tokens. Only callable by the owner.
     * @param mintPrice The new mint price.
     */
    function setMintPrice(uint256 mintPrice) external onlyOwner {
        _mintPrice = mintPrice;
    }

    /**
     * @dev Sets the URI for a specific token type. Only callable by the owner.
     * @param newURI The new URI.
     */
    function setTokenURI(string calldata newURI) external onlyOwner {
        _tokenURI = newURI;
    }

    /**
     * @dev Sets the contract's URI. Only callable by the owner.
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI) external onlyOwner {
        _contractURI = newContractURI;
    }

    /**
     * @dev Sets the seeds used for generating different types of tokens. Only callable by the owner.
     * @param seeds The new seeds.
     */
    function setSeeds(string[] memory seeds) external onlyOwner {
        _seedsCount = seeds.length;
        for (uint i = 0; i < _seedsCount; i++) {
            _seeds[i] = seeds[i];
        }
    }

    //////////// GETTERS

    /**
     * @dev Returns the status of the whitelist feature.
     * @return _isWhiteListActive A boolean indicating whether the whitelist is active.
     */
    function whiteListIsActive() external view returns (bool) {
        return _isWhiteListActive;
    }

    /**
     * @dev Returns the contract's URI.
     * @return _contractURI The URI of the contract.
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /**
     * @dev Returns the price of minting a token.
     * @return _mintPrice The mint price of a token.
     */
    function getMintPrice() external view returns (uint256) {
        return _mintPrice;
    }

    /**
     * @dev Returns the current total supply of tokens.
     * @return _supply The current total supply of tokens.
     */
    function totalSupply() public view override returns (uint256) {
        return _supply;
    }

    /**
     * @dev Returns the maximum supply of tokens.
     * @return _maxSupply The maximum supply of tokens.
     */
    function getMaxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Returns the pause status of the contract.
     * @return _isPaused A boolean indicating whether the contract is paused.
     */
    function isPaused() external view returns (bool) {
        return _isPaused;
    }

    /**
     * @dev Returns the array of seeds used for generating different types of tokens.
     * @return _seeds The array of seeds.
     */
    function getSeeds() external view returns (string[] memory) {
        string[] memory seeds = new string[](_seedsCount);
        for (uint i = 0; i < _seedsCount; i++) {
            seeds[i] = _seeds[i];
        }
        return seeds;
    }

    /**
     * @dev Returns the type of the box based on a given token ID.
     * @param tokenId The ID of the token.
     * @return A uint256 representing the type of the box.
     */
    function getBoxType(uint256 tokenId) public view returns (uint256) {
        uint256 number = getDigitAtPosition(tokenId);

        if (number == 0) {
            return 1;
        } else if (number >= 1 && number <= 3) {
            return 2;
        } else if (number >= 4 && number <= 9) {
            return 3;
        } else {
            return 0;
        }
    }

    /**
     * @dev Returns the digit at a specific position in the seeds array.
     * @param position The position of the digit.
     * @return digit The digit at the specified position.
     */
    function getDigitAtPosition(uint256 position) internal view returns (uint256) {
        require(_seedsCount > 0, "Unrevealed!");
        uint arrayIndex = position / 77;
        uint digitIndex = position % 77;

        require(arrayIndex < _seedsCount, "Position out of range");

        bytes memory numberBytes = bytes(_seeds[arrayIndex]);

        require(digitIndex < numberBytes.length, "Digit position out of range");

        uint digit = uint(uint8(numberBytes[digitIndex])) - 48; // Subtract 48 to convert from ASCII to integer.

        return digit;
    }
}
