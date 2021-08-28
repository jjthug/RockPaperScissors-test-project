pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RockPaperScissor {
    string constant public ROCK = 'ROCK';
    string constant public PAPER = 'PAPER';
    string constant public SCISSOR = 'SCISSOR';

    mapping(address => uint256) private _balances;

    address public owner;
    //Expiration time can be changed by owner
    uint32 public expirationTime = 1 days;

    //Assuming fixed fees, cannot be changed
    uint public fees = 0.01 ether;

    mapping(address => mapping(uint => bool)) public hasStaked;

    mapping(uint => Game) public games;

    //maps game id to result
    mapping(uint => string) public result;

    uint gameCount = 1;
    
    struct Game{
        uint gameId;
        address payable player1;
        address payable player2;
        bool hasStakedPlayer1;
        bool hasStakedPlayer2;
        string choicePlayer1;
        string choicePlayer2;
        uint endTime;
        bool isGameReady;
    }

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

    event Response(bool sent, bytes data);
    


  constructor() {
    
    owner = msg.sender;
  }

  modifier isOwner() {
    require(msg.sender == owner);
    _;
  }

  function changeExpirationTime(uint32 _newExpirationTime) public isOwner {
    expirationTime = _newExpirationTime;
  }

//Creating a game with both the player addresses as input
//msg.sender must be one of the players
  function createGame(address payable player1, address payable player2) public {
    require(msg.sender != address(0x0));
    require(player1 != address(0x0));
    require(player2 != address(0x0));
    require(msg.sender == player1 || msg.sender == player2);

    games[gameCount] = Game(gameCount, player1, player2, false, false,"","", block.timestamp + expirationTime, false);
    emit GameCreated(gameCount, player1, player2, false, false, "", "", games[gameCount].endTime, false);
    gameCount++ ;
  }


  function payGameFees(uint _gameId, address player) public payable validPlayer(_gameId) {
    require(isValidGame(_gameId), "Invalid Game or expired");

    require(msg.value >= fees || _balances[player] >= fees);

    if(msg.value >= fees) {

    //extra ether will added to balance of player not message sender
    //the extra balance of player cannot be withdrawn
    _balances[player] += msg.value - fees;

    //reentrancy attack will not abuse the contract in this scenario
    (bool sent, bytes memory data) = address(this).call{value: msg.value}("");
    emit Response(sent, data);
    require(sent, "Failed to send Ether");

    }
    else{ 
        _balances[player] -= fees; }
    
    if(player == games[_gameId].player1){
        games[_gameId].hasStakedPlayer1 = true;}
    else
        {games[_gameId].hasStakedPlayer2 = true;}
  }

//The player can withdraw if other player is not cooperating by staking in the game
  function withdrawFromGame(uint _gameId) public validPlayer(_gameId){
    require(!games[_gameId].isGameReady);
    Game storage game = games[_gameId];
    game.endTime = 0;
    //Transfer back the staked tokens to the players who staked
    if(game.hasStakedPlayer1){
        address payable player = game.player1;
        player.call{value: fees};
        }
    else{
        address payable player = game.player2;
        player.call{value: fees};
    }
  }


  //Check if the input contains either of the keywords "ROCK", "PAPER" or "SCISSOR"
  function isRockPaperScissor(string memory choice) internal pure returns (bool) {
    return(keccak256(abi.encodePacked((choice))) == keccak256(abi.encodePacked((ROCK))) 
        || keccak256(abi.encodePacked((choice))) == keccak256(abi.encodePacked((PAPER)))
        || keccak256(abi.encodePacked((choice))) == keccak256(abi.encodePacked((SCISSOR))));
  }

//Checks if game is already expired
  function isValidGame(uint _gameId) internal view returns (bool) {
    require(_gameId <= gameCount);
    require(games[_gameId].endTime <= block.timestamp);
    return true;
  }

//Checks if msg.sender is one of the players in the particular game
    modifier validPlayer(uint _gameId) {
    require(msg.sender != address(0x0));
    require(games[_gameId].player1 == msg.sender || games[_gameId].player2 == msg.sender);
    _;
  }

//Finds the winner and returns the winner address
  function getWinner(uint _gameId) internal returns(uint8){
    Game storage game = games[_gameId];
    //Todo LOGIC

    if(keccak256(abi.encodePacked((game.choicePlayer1))) == keccak256(abi.encodePacked((game.choicePlayer2))))
        {result[_gameId] = "Tie";
    return 0;
}

    if(keccak256(abi.encodePacked((game.choicePlayer1))) == keccak256(abi.encodePacked((ROCK))))
    {
        if(keccak256(abi.encodePacked((game.choicePlayer2))) == keccak256(abi.encodePacked((PAPER))))
        {result[_gameId] = "Player2";
         return 2;   }
        else
        {result[_gameId] = "Player1";
         return 1;   }
   }

   if(keccak256(abi.encodePacked((game.choicePlayer1))) == keccak256(abi.encodePacked((PAPER))))
    {
    if(keccak256(abi.encodePacked((game.choicePlayer2))) == keccak256(abi.encodePacked((ROCK))))
        {result[_gameId] = "Player1";
        return 1;   }
    else
        {result[_gameId] = "Player2";
         return 2;   }
    }

   if(keccak256(abi.encodePacked((game.choicePlayer1))) == keccak256(abi.encodePacked((SCISSOR))))
    {
    if(keccak256(abi.encodePacked((game.choicePlayer2))) == keccak256(abi.encodePacked((ROCK))))
        {result[_gameId] = "Player2";
        return 2;   }
    else
         {result[_gameId] = "Player1";
         return 1;   }
    }
    }

//Make your game choice
  function makeGameChoice(string memory choice, uint _gameId) public validPlayer(_gameId){
    require(isValidGame(_gameId), "Invalid Game or expired");
    require(isRockPaperScissor(choice), "Invalid choice! Please choose ROCK PAPER or SCISSOR");

    Game storage game = games[_gameId];
    if(msg.sender == games[_gameId].player1) {
        game.choicePlayer1 = choice;
    game.hasStakedPlayer1 = true;}

    if(msg.sender == games[_gameId].player2) {
     game.choicePlayer2 = choice;
     game.hasStakedPlayer2 = true;
    }

    string memory empty = "";
    if(game.hasStakedPlayer1 && game.hasStakedPlayer2 
        && keccak256(abi.encodePacked((game.choicePlayer1))) != keccak256(abi.encodePacked((empty))) 
        && keccak256(abi.encodePacked((game.choicePlayer2))) != keccak256(abi.encodePacked((empty)))) {
      game.isGameReady = true;
      games[_gameId] = game;
      uint8 winner = getWinner(_gameId);
      if(winner == 0){

        address payable player = game.player1;
        player.call{value: fees};

        player = game.player2;
        player.call{value: fees};
    }
    else{
        address payable player;
        if(winner == 1){
             player = game.player1;
             player.call{value: 2*fees};}
        else
        {
            player = game.player2;
            player.call{value: 2*fees};}

        }
    
    }
  }
}