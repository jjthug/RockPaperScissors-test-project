pragma solidity ^0.8.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RockPaperScissor is ERC20 {
    string constant ROCK = 'ROCK';
    string constant PAPER = 'PAPER';
    string constant SCISSOR = 'SCISSOR';

    address public owner;
    uint32 public expirationTime = 1 days;

    //Fees will be set by the owner
    uint16 public fees = 0.01 ether;

    mapping(address => mapping(uint => bool)) public hasStaked;

    mapping(uint => Game) public games;

    uint gameCount = 1;
    
    struct Game{
        uint gameId;
        address player1;
        address player2;
        bool hasStakedPlayer1;
        bool hasStakedPlayer2;
        string choicePlayer1;
        string choicePlayer2;
        uint endTime;
        bool isGameReady;
    };

    event GameCreated(
        uint gameId,
        address payable player1,
        address payable player2,
        bool hasStakedPlayer1,
        bool hasStakedPlayer2,
        string choicePlayer1,
        string choicePlayer2,
        uint endTime,
        bool isGameReady
        );

  constructor() public {
    owner = msg.sender;
  }

  modifier isOwner() {
    require(msg.sender == owner);
    _;
  }

  function changeFees(uint16 _newFees) public isOwner {
    fees = _newFees;
  }

  function changeExpirationTime(uint32 _newExpirationTime) public isOwner {
    expirationTime = _newExpirationTime;
  }


  function createGame(address player1, address player2) public {
    require(msg.sender != address(0x0));
    require(player1 != address(0x0));
    require(player2 != address(0x0));

    games[gameCount] = Game(gameCount, player1, player2, false, false,"","", now + expirationTime, false);
    emit GameCreated(gameCount, player1, player2, false, false, "", "", games[gameCount].endTime, false);
    gameCount++ ;
  }

  //Anyone can pay for any player in the game
  function payGameFees(uint _gameId, address player) public payable {
    require(validGame(_gameId), "Invalid Game or expired");
    require(msg.value >= fees);

    _balances[msg.sender] += msg.value - fees;
    hasStaked[msg.sender][_gameId] = true;
    (bool sent, bytes memory data) = address(this).call{value: msg.value}("");
    require(sent, "Failed to send Ether");
  }


  function isRockPaperScissor(string choice) internal view returns (bool) {
    return(keccak256(abi.encodePacked((choice))) == keccak256(abi.encodePacked((ROCK))) 
        || keccak256(abi.encodePacked((choice))) == keccak256(abi.encodePacked((PAPER)))
        || keccak256(abi.encodePacked((choice))) == keccak256(abi.encodePacked((SCISSOR))));
  }


  function validGame(uint _gameId) internal view returns (bool) {
    require(_gameId <= gameCount);
    require(games[_gameId].creationTime + games[_gameId].expirationTime);
    return true;
  }

    modifier validPlayer(uint _gameId) {
    require(games[_gameId].player1 == msg.sender || games[_gameId].player2 == msg.sender);
    _;
  }


  function getWinner(uint _gameId) internal view returns(address){
    Game storage game = games[_gameId];
    //Todo LOGIC
  }


  function makeGameChoice(string choice, uint _gameId) public payable validPlayer(_gameId){
    require(validGame(_gameId), "Invalid Game or expired");
    require(isRockPaperScissor(choice), "Invalid choice! Please choose "ROCK" "PAPER" or "SCISSOR");

    Game storage game = games[_gameId];
    if(msg.sender == games[_gameId].player1) {
        game.player1 = choice;
    game.hasStakedPlayer1 = true;}

    if(msg.sender == games[_gameId].player2) {
    game.player2 = choice;
    game.hasStakedPlayer2 = true;
    }

    if(game.hasStakedPlayer1 && game.hasStakedPlayer2) {
    game.isGameReady = true;
    games[_gameId] = game;
    address payable winner = getWinner(_gameId);
    winner.call{value: 2*fees}("");
    }   

  }
}