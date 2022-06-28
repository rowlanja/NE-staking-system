// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Items is ERC1155, Ownable, AccessControl {
    
    //maps addresses to boolean flags for allowance and revocation of allowance to receive tokens
    //an address mapped to 'false' will be blocked from being sent tokens
    // mapping(address => bool) internal allowedAddresses;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    
    constructor () ERC1155("https://example.cdn/QmVXVMJgyfAkErneZGnDUqzC6hGFctXJVrRETyaqRc3LUK/{id}.json") 
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        super._mintBatch(to, ids, amounts, data);
    }
    
    function burnBatch(address to, uint256[] memory ids, uint256[] memory amounts) public onlyOwner {
        super._burnBatch(to, ids, amounts);
    }

        //burn a single type of token with the help of token id
    function burn(uint _id,uint _tokenAmount) public onlyOwner{
        _burn(owner(),_id,_tokenAmount);
    }

    //burn a batch of tokens
    function burnBatch(uint[] memory _ids,uint[] memory _tokensAmounts) public onlyOwner{
        _burnBatch(owner(),_ids,_tokensAmounts);
    }
    
    
    // /**
    //  * allowAddress: adds an Ethereum address to the allow list to transfer tokens
    //  * @param from - the Ethereum address of the sender to add to the allow list
    //  * @param allow - the boolean value denoting whether the to address is allowed to transfer/send tokens
    //  * 
    //  * @dev provide the address for the sender and boolean 'false' to deny and 'true' to allow token transfers
    //  */
    // function allowAddress(address from, bool allow) public onlyOwner {
    //     allowedAddresses[from] = allow;
    // }
    
    
    // function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    //     internal virtual override
    // {
    //     super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

    //     // if(msg.sender != owner()) { 
    //     //     require(_validSender(from), "ERC155WithSafeTransfer: this address does not have permission to transfer tokens");
    //     // }
    // }

    // /**
    //  * _validSender: checks the 
    //  * @param from - the Ethereum address of the sender to check against the allow list
    //  * 
    //  * @dev the allow list is only checked for 'true' or 'false'; transfers initiated by the contract owner are not checked
    //  * 
    //  */
    // function _validSender(address from) private view returns (bool) {
    //     //add logic for 'magic phrase' here to validate recipients?
    //     return allowedAddresses[from];
        
    // }
        // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}