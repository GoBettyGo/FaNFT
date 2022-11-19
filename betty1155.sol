// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../extension/erc20.sol";
import "../extension/vrf.sol";

contract Betty is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable,ERC1155SupplyUpgradeable, UUPSUpgradeable,vrfContract {
    using StringsUpgradeable for uint256;

    string private _name;
    string private _symbol;

    address public saleWallet;
    uint256 constant Gold = 1;
    uint256 constant Silver = 2;
    uint256 constant Copper = 3;
    mapping(address => uint) public orders;
    uint256 public salesCount;
    uint256 public revealCount;
    uint256 public revealFee;
    uint256 public maxTokenId;

    IERC20 public feeTokenBUSD;
    uint256 public buyFeeBUSD;
    IERC20 public feeTokenGBY;
    uint256 public buyFeeGBY;

    uint64 internal subId;

    event OpenMysteryBox(uint256 requestId,uint256 tokenId,address requestAddress);

    struct NFT {
        uint256 tokenId;
        uint256 team;
        uint256 attribute;
        uint256 amount;
    }

    struct Token {
        uint256 tokenId;
        uint256 amount;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address feeTokenBUSD_,
        address feeTokenGBY_,
        uint64 _subId) initializer public {
        __ERC1155_init("");
        __Ownable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        _name=name_;
        _symbol=symbol_;
        feeTokenBUSD=IERC20(feeTokenBUSD_);
        feeTokenGBY=IERC20(feeTokenGBY_);
        buyFeeBUSD = 30 ether;
        revealFee = 0.0002 ether;
        buyFeeGBY = 40 ether;

        __init_VrfContract(2000000, 5);
        subId = _subId;
    }

    function _keyHash() internal override returns (bytes32){
        return bytes32(0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04);
    }

    function _subscriptionId() internal override returns (uint64) {
        return subId;
    }

    function _processRandomnessFulfillment(uint256 requestId, address requestAddress, uint256 randomness) internal override{
        uint256 RandomNum=seedToRandom(randomness);
        uint256 count=balanceOf(saleWallet);
        uint256 index=getIndexByTotalIndex(saleWallet,RandomNum%count);
        _revealNFT(requestId,index,requestAddress);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function subscriptionId() public view returns (uint64) {
        return subId;
    }

    function updateSubscriptionId(uint64 _subId) external onlyOwner {
        subId=_subId;
    }

    function updateBuyFeeBUSD(uint256 _fee) external onlyOwner {
        buyFeeBUSD = _fee;
    }

    function updateBuyFeeGBY(uint256 _fee) external onlyOwner {
        buyFeeGBY = _fee;
    }

    function updateRevealFee(uint256 _fee) external onlyOwner {
        revealFee = _fee;
    }

    function baseURI() public view returns (string memory) {
        return uri(0);
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function updateVRFCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner{
        callbackGasLimit=_callbackGasLimit;
        return;
    }

    function updateVRFRequestConfirmations(uint16 _requestConfirmations) external onlyOwner{
        requestConfirmations=_requestConfirmations;
        return;
    }

    function setSaleWallet(address saleAddress) external onlyOwner{
        saleWallet=saleAddress;
        return;
    }

    function setFeeTokenBUSD(address token) external onlyOwner{
        feeTokenBUSD=IERC20(token);
        return;
    }

    function setFeeTokenGBY(address token) external onlyOwner{
        feeTokenGBY=IERC20(token);
        return;
    }

    function safeMint(address to, uint256 id,uint256 quantity) public onlyOwner{
        mint(to, id,quantity,"");
    }


    function safeMint(
        address to,
        uint256 id,
        uint256 quantity,
        bytes memory _data
    ) public onlyOwner{
        mint(to, id,quantity,_data);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
    public
    onlyOwner
    {
        _mint(account, id, amount, data);
        if(id>maxTokenId){
            maxTokenId=id;
        }
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    public
    onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
        for( uint256 i; i < ids.length; ++i ){
            if(ids[i]>maxTokenId){
                maxTokenId=ids[i];
            }
        }
    }

    function getSales() public view returns (Token[] memory) {
        return tokensOfOwner(saleWallet);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(exists(tokenId), "URI query for nonexistent token");
        string memory baseURI = uri(tokenId);
        string memory tokenIdString=string.concat(tokenId.toString(),".json");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenIdString)) : "";
    }

    function calAttribute(uint256 tokenId) public view returns (uint256) {
        require(tokenId<=maxTokenId && tokenId >= 0, "TokenId out of bounds.");
        uint256 mod=tokenId%3;
        if (mod == 0) {
            return Gold;
        }else if (mod==1){
            return Silver;
        }else{
            return Copper;
        }
    }

    function calTeam(uint256 tokenId) public view returns (uint256) {
        require(tokenId<=maxTokenId && tokenId >= 0, "TokenId out of bounds.");
        return tokenId/3;
    }

    function calAmount(uint256 tokenId) public view returns (uint256) {
        require(tokenId<=maxTokenId && tokenId >= 0, "TokenId out of bounds.");
        uint256 mod=tokenId%3;
        if (mod == 0) {
            return 100;
        }else if (mod==1){
            return 200;
        }else{
            return 700;
        }
    }

    function _buyNFT() internal{
        orders[_msgSender()]+=1;
        salesCount++;
    }

    function balanceOf(address owner) public view returns (uint256) {
        uint256 count;
        for( uint256 i; i <= maxTokenId; ++i ){
            count+=balanceOf(owner,i);
        }
        return count;
    }

    function tokensCountOf(address owner) public view returns (uint256) {
        uint256 count;
        for( uint256 i; i <= maxTokenId; ++i ){
            if(balanceOf(owner,i)>0){
                count++;
            }
        }
        return count;
    }

    function getLeftSalesAmount() public view returns (uint256) {
        uint256 count=balanceOf(saleWallet);
        return count+revealCount-salesCount;
    }

    function buyNFTsByBUSD(uint amount) public{
        require(amount>0, "Amount must be more than zero. ");
        require(getLeftSalesAmount()>=amount, "NFTs are insufficient in quantity. ");

        uint256 moneyAmount;
        uint boughtCount=balanceOf(_msgSender())+orders[_msgSender()];
        if(boughtCount==0){
            if(amount==1){
                moneyAmount=buyFeeBUSD*amount;
            }else {
                moneyAmount=buyFeeBUSD*2-buyFeeBUSD/3+ buyFeeBUSD/2*(amount-2);
            }
        }else if (boughtCount==1){
            moneyAmount=buyFeeBUSD-buyFeeBUSD/3 + buyFeeBUSD/2*(amount-1);
        }else {
            moneyAmount=buyFeeBUSD/2*amount;
        }

        feeTokenBUSD.transferFrom(_msgSender(), saleWallet, moneyAmount);
        for(uint i; i < amount; i++){
            _buyNFT();
        }
    }

    function buyNFTsByGBY(uint amount) public{
        require(amount>0, "Amount must be more than zero. ");
        require(getLeftSalesAmount()>=amount, "NFTs are insufficient in quantity. ");
        feeTokenGBY.transferFrom(_msgSender(), saleWallet, buyFeeGBY*amount);
        for(uint i; i < amount; i++){
            _buyNFT();
        }
    }

    function airdropNFT(address to) public onlyOwner{
        require(getLeftSalesAmount()>0, "NFTs are insufficient in quantity. ");
        require(to != address(0), "Airdrop to the zero address");
        orders[to]+=1;
        salesCount++;
    }

    function tokensOfOwner(address owner) public view returns (Token[] memory) {
        require(owner != address(0), "Tokens query for the zero address");

        uint256 count=tokensCountOf(owner);

        Token[] memory tokens = new Token[](count);
        uint index;
        for(uint i; i <= maxTokenId; i++){
            if(balanceOf(owner,i)>0){
                Token memory newToken = Token(i,balanceOf(owner,i));
                tokens[index]=newToken;
                index++;
            }
        }
        return tokens;
    }

    function _revealNFT(uint256 requestId,uint256 index,address requestAddress) internal{
        Token[] memory Sales=tokensOfOwner(saleWallet);
        require(Sales.length>0, "NFTs have been revealed out. ");
        require(index < Sales.length, "ERC721: index out of bounds");
        require(orders[requestAddress]>0, "RequestAddress have no blind box");
        _safeTransferFrom(saleWallet,requestAddress,Sales[index].tokenId,1,"");
        orders[requestAddress]-=1;
        revealCount++;
        emit OpenMysteryBox(requestId,Sales[index].tokenId,requestAddress);
    }

    function revealANFT() external payable{
        require(orders[_msgSender()]>0, "You have no blind box");
        require(msg.value >= revealFee);
        _requestVRF();
    }

    function NFTsOfOwner(address owner) public view returns (NFT[] memory) {
        Token[] memory tokens = tokensOfOwner(owner);
        NFT[] memory NFTs = new NFT[](tokens.length);
        for(uint i; i < tokens.length; i++){
            uint256 team=calTeam(tokens[i].tokenId);
            uint256 attribute=calAttribute(tokens[i].tokenId);
            NFT memory newNFT = NFT(tokens[i].tokenId,team,attribute,tokens[i].amount);
            NFTs[i]=newNFT;
        }
        return NFTs;
    }

    function getNFTById(uint256 tokenId) public view returns (NFT memory) {
        uint256 team=calTeam(tokenId);
        uint256 attribute=calAttribute(tokenId);
        uint256 amount=calAmount(tokenId);
        NFT memory newNFT = NFT(tokenId,team,attribute,amount);
        return newNFT;
    }

    function _createRandomNum(uint256 _mod) internal view returns (uint256) {
        uint256 randomNum = uint256(
            keccak256(abi.encodePacked(block.timestamp, _msgSender()))
        );
        return randomNum % _mod;
    }

    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    function getIndexByTotalIndex(address owner,uint256 index) public view returns(uint256){
        Token[] memory tokens=tokensOfOwner(owner);
        uint256 i;
        for(i=0; i < tokens.length && index+1 > tokens[i].amount; i++){
            index-=tokens[i].amount;
        }
        return i;
    }

    function totalSupply() public view returns (uint256) {
        uint256 total;
        for( uint256 i; i <= maxTokenId; ++i ){
            total+=totalSupply(i);
        }
        return total;
    }

    function withdrawAll(address payable _to) public onlyOwner{
        _to.transfer(address(this).balance);
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    internal
    override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
