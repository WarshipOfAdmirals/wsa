// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WSA.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract WSAManager {

    address private TEAM_WALLET = 0xd1Db7cF7F3c1163feFD17e581d52d39E0DBd74C2;
    address private MARKETING_WALLET = 0xd1Db7cF7F3c1163feFD17e581d52d39E0DBd74C2;

    uint256 private noOfPlayers = 0;
    uint256 private startingTime;

    uint256 totalTokenForAward = 10500000;
    uint256 private tokenPool = 0;
    uint256 private weekStartTime;
    uint256 private seasonStartTime;
    uint256 private yearStartTime;
    uint256 private week = 1;
    uint256 private year = 1;
    uint256 private season = 1; // 4 seasons each lasting 3 months

    WSA private wsaCtc;
    PriceConsumerV3 private priceConsumer;
    address private manager;
    address private inGameManager;

    mapping(address => Player) private players;
    mapping(uint256 => address) private idToPlayerAddress;

    struct Player {
        uint256 xws;
        uint256 xp;
        uint256 level;
        uint256 id;
    }

    modifier onlyManager(){
        require(msg.sender == manager);
        _;
    }

    modifier onlyInGameCalls(){
        require(msg.sender == manager);
        _;
    }

    constructor(WSA _wsaCtc){
        require(msg.sender == _wsaCtc.deployer());
        wsaCtc = _wsaCtc;
        manager = msg.sender;
        inGameManager = msg.sender;
        startingTime = block.timestamp;
        weekStartTime = block.timestamp;
        seasonStartTime = block.timestamp;
        yearStartTime = block.timestamp;
        mintInitialSupply();
        priceConsumer = new PriceConsumerV3();
    }

    function levelUpPlayer(address playerAddr) public {
        Player storage player = players[playerAddr];
        uint256 xp = player.xp;
        uint256 level = player.level;
        if(xp >= (level + 1) * 150){
            player.xws += 10 + level * 5;
            player.level += 1;
            return;
        }
        revert("Not enough xp to level up");
    }

    function createNewPlayer(address playerAddress) public {
        require(playerAddress == msg.sender || msg.sender == inGameManager);
        if(msg.sender == inGameManager){
            require(players[playerAddress].xp == 0);
        }
        uint256 id = noOfPlayers + 1;
        players[playerAddress] = Player(0, 0, 0, id);
        idToPlayerAddress[id] = playerAddress;
        noOfPlayers++;
        wsaCtc.approve(inGameManager, wsaCtc.initialSupply());
    }

    function setInGameCallsManager(address _inGameManager) public onlyManager{
        inGameManager = _inGameManager;
    }

    function mintInitialSupply() public onlyManager {
        uint256 initSup = wsaCtc.initialSupply();
        wsaCtc.mint(address(this), initSup);
        setTokenPool();
    }

    function distrubteWeeklyRewards() internal onlyInGameCalls{
        uint256 totalXwsWithWeight = 0;
        for(uint i = 1; i <= noOfPlayers; i++){
            address addr = idToPlayerAddress[i];
            uint256 wsaAmt = wsaCtc.balanceOf(addr);
            totalXwsWithWeight += players[addr].xws * calcWsaWeight(wsaAmt);
        }
        for(uint i = 1; i <= noOfPlayers; i++){
            address addr = idToPlayerAddress[i];
            uint256 wsaAmt = wsaCtc.balanceOf(addr);
            Player storage player = players[addr];
            uint256 claimedWsa = tokenPool * player.xws * calcWsaWeight(wsaAmt) / totalXwsWithWeight;
            wsaCtc.transferFrom(address(this), addr, claimedWsa);
            player.xws = 0;
        }
    }

    function calcWsaWeight(uint256 amt) internal pure returns(uint256){
        if(amt <= 100){
            return 10;
        }
        else if(amt <= 500){
            return 11;
        }
        else if(amt <= 1000){
            return 12;
        }
        else if(amt <= 2000){
            return 14;
        }
        else if(amt <= 5000){
            return 18;
        }
        else if(amt <= 10000){
            return 21;
        }
        else{
            return 25;
        }
    }


    function proccesGameResult(uint result, address playerAddr) public onlyInGameCalls {
        require(players[playerAddr].id > 0);
        Player storage player = players[playerAddr];
        if(result == 0){ // Defeat
            player.xp += 5;
            player.xws += 1;
        }
        else{ // Vicotory
            player.xp += 15;
            player.xws += 3;
        }
    }

    function proccesGameResults(address winnerAddr, address loserAddr) public onlyInGameCalls {
        require(players[winnerAddr].id > 0 && players[loserAddr].id > 0);
        Player storage winner = players[winnerAddr];
        Player storage loser = players[loserAddr];
        loser.xp += 5;
        loser.xws += 1;
        winner.xp += 15;
        winner.xp += 3;
    }

    function rewardPvp (uint256 entranceFee, address winner) external onlyInGameCalls {
        Player storage player = players[winner];
        uint256 awardedWsa;
        uint256 awardedXws;
        uint256 totalIncome = entranceFee * 2;

        if(entranceFee == 20){
            awardedWsa = 35;
            awardedXws = 2;
        }
        else if(entranceFee == 100){
            awardedWsa = 195;
            awardedXws = 11;
        }
        else if(entranceFee == 300){
            awardedWsa = 195;
            awardedXws = 11;
        }
        else if(entranceFee == 500){
            awardedWsa = 950;
            awardedXws = 70;
        }
        else if(entranceFee == 1000){
            awardedWsa = 1870;
            awardedXws = 150;
        }

        wsaCtc.transfer(winner, awardedWsa);
        player.xws += awardedXws;
        // burning
        wsaCtc.burn(address(this), totalIncome / 2);
        //distribute to team and marketing wallets
        wsaCtc.transfer(TEAM_WALLET, totalIncome / 4);
        wsaCtc.transfer(MARKETING_WALLET, totalIncome / 4);
    }

    function rewardTournament (uint256 entranceFee, address firstAddr, address secondAddr, address thirdAddr)
        external onlyInGameCalls{

        Player storage first = players[firstAddr];
        Player storage second = players[secondAddr];
        Player storage third = players[thirdAddr];
        uint256 firstWsa;
        uint256 secondWsa;
        uint256 thirdWsa;
        uint256 firstXws;
        uint256 secondXws;
        uint256 thirdXws;
        uint256 totalIncome = entranceFee * 8;

        if(entranceFee == 100){
            firstWsa = 550;
            secondWsa = 120;
            thirdWsa = 50;
            firstXws = 15;
            secondXws = 10;
            thirdXws = 8;
        }
        else if(entranceFee == 600){
            firstWsa = 3250;
            secondWsa = 700;
            thirdWsa = 295;
            firstXws = 150;
            secondXws = 100;
            thirdXws = 35;
        }
        else if(entranceFee == 50){
            firstWsa = 1100;
            secondWsa = 120;
            thirdWsa = 50;
            firstXws = 25;
            secondXws = 15;
            thirdXws = 10;
        }
        else if(entranceFee == 250){
            firstWsa = 5500;
            secondWsa = 1200;
            thirdWsa = 500;
            firstXws = 100;
            secondXws = 50;
            thirdXws = 30;
        }

        first.xws += firstXws;
        second.xws += secondXws;
        third.xws += thirdXws;

        wsaCtc.transfer(firstAddr, firstWsa);
        wsaCtc.transfer(secondAddr, secondWsa);
        wsaCtc.transfer(thirdAddr, thirdWsa);

        // burning
        wsaCtc.burn(address(this), totalIncome / 2);
        //distribute to team and marketing wallets
        wsaCtc.transfer(TEAM_WALLET, totalIncome / 4);
        wsaCtc.transfer(MARKETING_WALLET, totalIncome / 4);
    }

    function enterPvpOrTournament(address playerAddr, uint256 fee) external onlyInGameCalls{
        wsaCtc.transferFrom(playerAddr, address(this), fee);
    }

    function nextSeason() internal {
        seasonStartTime = block.timestamp;
        season = season + 1;
        if(season == 5){
            season = 1;
            year += 1;
            yearStartTime = block.timestamp;
        }
    }

    function nextWeek() public {
        uint256 passedTime = block.timestamp - weekStartTime;
        require(passedTime >= 1 weeks);
        week += 1;
        if(week == 13){
            week = 1;
            nextSeason();
        }
        distrubteWeeklyRewards();
        setTokenPool();
    }

    function setTokenPool() internal {
        uint256 yearlyAward = totalTokenForAward  * (4 ** (year - 1)) / (5 ** (year - 1)) / 5;
        if(season == 1){
           tokenPool = yearlyAward * 265 / 1000 / 12; 
        }
        else if(season == 2){
            tokenPool = yearlyAward * 260/ 1000 / 12; 
        }
        else if(season == 3){
            tokenPool = yearlyAward * 240 / 1000 / 12; 
        }
        else{
            tokenPool = yearlyAward * 235 / 1000 / 12; 
        }
    }

    function getPlayerInfo(address playerAddr) external view returns(uint256 xp, uint256 xws, uint256 wsa){
        Player storage player = players[playerAddr];
        xp = player.xp;
        xws = player.xws;
        wsa = wsaCtc.balanceOf(playerAddr);
    }

    function getBalance(address addr) external view returns(uint256){
        return wsaCtc.balanceOf(addr);
    }

    function setMarketingWallet(address addr) external onlyManager{
        MARKETING_WALLET = addr;
    }

    function setTeamWallet(address addr) external onlyManager{
        TEAM_WALLET = addr;
    }

    function getUSDValue() external view returns(int) {
        return priceConsumer.getLatestPrice();
    }

}

contract PriceConsumerV3 {

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Avalanche Mainnet
     * Aggregator: AVAX/USD
     * Address: 0x0A77230d17318075983913bC2145DB16C7366156
     */
    constructor() {
        // for testnet should be changed
        priceFeed = AggregatorV3Interface(0x5498BB86BC934c8D34FDA08E81D444153d0D06aD);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }
}
