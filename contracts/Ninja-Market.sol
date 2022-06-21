// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract Marketplace is ReentrancyGuard {

    // Variables
    address payable public immutable feeAccount; // the account that receives fees
    uint public immutable feePercent; // the fee percentage on sales 
    uint public itemCount; 

    struct Item {
        IERC721 nft;
        uint index;
        uint price;
        address payable seller;
        bool sold;
    }

    // itemId -> Item
    mapping(uint => Item) public items;

    uint[] public itemIds;

    event Offered(
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );
    event Deoffered(
        uint itemId,
        address indexed seller
    );
    event Bought(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    constructor(uint _feePercent) {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
    }

    // Make item to offer on the marketplace
    function listItem(IERC721 _nft, uint _tokenId, uint _price) external nonReentrant {
        // require(_price > 0, "Price must be greater than zero");
        // transfer nft
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        // add new item to items mapping
        items[_tokenId] = Item (
            _nft,
            itemIds.length,
            _price,
            payable(msg.sender),
            false
        );
        itemIds.push(_tokenId);
        // emit Offered event
        emit Offered(
            address(_nft),
            _tokenId,
            _price,
            msg.sender
        );
    }

        // Make item to offer on the marketplace
    function delistItem(uint _tokenId) external payable nonReentrant {
        require(items[_tokenId].seller == msg.sender, "Caller doesnt own listed item");

        Item memory item = items[_tokenId];

        item.nft.transferFrom(address(this), msg.sender, _tokenId);
        //remove itemID from listed itemID list
        itemIds[item.index] = itemIds[itemIds.length-1];
        // remove itemId
        itemIds.pop(); 
        // remove item to items mapping
        delete items[_tokenId];


        // emit Offered event
        emit Deoffered(
            _tokenId,
            msg.sender
        );
    }

    function purchaseItem(uint _tokenId) external payable nonReentrant {
        // uint _totalPrice = getTotalPrice(_tokenId);
        Item storage item = items[_tokenId];
        require(msg.value >= item.price, "not enough ether to cover item price and market fee");
        require(!item.sold, "item already sold");
        // pay seller and feeAccount
        item.seller.transfer(msg.value);
        // feeAccount.transfer(_totalPrice - item.price);
        // update item to sold
        // item.sold = true;
        // transfer nft to buyer
        item.nft.transferFrom(address(this), msg.sender, _tokenId);

        //remove itemID from listed itemID list
        itemIds[item.index] = itemIds[itemIds.length-1];
        // remove itemId
        itemIds.pop(); 
        // remove item to items mapping
        delete items[_tokenId];


        // emit Bought event
        emit Bought(
            _tokenId,
            address(item.nft),
            _tokenId,
            item.price,
            item.seller,
            msg.sender
        );
    }
    function getTotalPrice(uint _itemId) view public returns(uint){
        return((items[_itemId].price*(100 + feePercent))/100);
    }

    function getItemIds() public view returns (uint[] memory) {
        return itemIds;
    }
}
