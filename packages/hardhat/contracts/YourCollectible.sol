pragma solidity >=0.6.0 <0.7.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import 'base64-sol/base64.sol';

import './HexStrings.sol';
import './ToColor.sol';

import "hardhat/console.sol";
//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

contract YourCollectible is ERC721, Ownable {

  using Strings for uint256;
  using HexStrings for uint160;
  using ToColor for bytes3;

  constructor() public ERC721("Dodo Birds Fight", "DODO") {
    // create a junk bird for index 0
    dodos.push(Dodo({
      wins: 0,
      color: 0,
      available: false
    }));
    // same for fights
    fights.push(Fight({
      id1: 0,
      id2: 0,
      block: 0
    }));
  }

  struct Fight {
      uint256 id1;
      uint256 id2;
      uint256 block;
  }

  // An array of 'Todo' structs
  Fight[] public fights;


  struct Dodo {
      uint256 wins;
      bytes3 color;
      bool available;
  }

  // An array of 'Todo' structs
  Dodo[] public dodos;
  //mapping (uint256 => bool) public available;

  //mapping (uint256 => bytes3) public color;
  //mapping (uint256 => uint256) public chubbiness;

  uint256 mintDeadline = block.timestamp + 24 hours;

  function mintItem()
      public
      returns (uint256)
  {
      require( block.timestamp < mintDeadline, "DONE MINTING");
      //_tokenIds.increment();

      uint256 id = dodos.length;
      _mint(msg.sender, id);

      bytes32 predictableRandom = keccak256(abi.encodePacked( blockhash(block.number-1), msg.sender, address(this), id ));
      //color[id] =
      //chubbiness[id] = 35+((55*uint256(uint8(predictableRandom[3])))/255);

      dodos.push(Dodo({
        wins: 0,
        color: bytes2(predictableRandom[0]) | ( bytes2(predictableRandom[1]) >> 8 ) | ( bytes3(predictableRandom[2]) >> 16 ),
        available: true
      }));

      return id;
  }

  event Challenge(uint256 indexed id1, uint256 indexed id2, uint256 blocknumber, uint256 fightid);

  function challenge(uint256 id1, uint256 id2) public returns (uint256){
    Dodo storage dodo1 = dodos[id1];
    require(dodo1.available, "first dodo not available");
    Dodo storage dodo2 = dodos[id2];
    require(dodo2.available, "second dodo not available");

    require(ownerOf(id1) == msg.sender, "not your dodo!");

    dodo1.available=false;
    dodo2.available=false;

    fights.push(Fight({
      id1: id1,
      id2: id2,
      block: block.number+1
    }));

    emit Challenge(id1,id2,block.number+1,fights.length-1);

    return fights.length-1;
  }

  function process(uint256 fightid) public {
     Fight storage fight = fights[fightid];
     require(fight.id1>0,"unknown fight");
     require(block.number>fight.block,"not yet");

     Dodo storage dodo1 = dodos[fight.id1];
     Dodo storage dodo2 = dodos[fight.id2];

     bytes32 lessPredictableRandom = keccak256(abi.encodePacked( blockhash(fight.block), msg.sender, address(this), fightid ));




     uint8 index = 0;

     bool whosTurn = false;

     uint8 coinflip = uint8(lessPredictableRandom[index++]);
     if(coinflip>=128){
       whosTurn=true;
     }

     uint8 health1 = 100;
     uint8 health2 = 100;
     uint8 divider = 10;

     while(health1>0&&health2>0){

       if(index>=32){
         lessPredictableRandom = keccak256(abi.encodePacked( blockhash(fight.block), msg.sender, address(this), fightid, lessPredictableRandom ));
         index=0;
       }

       uint8 thisDamage = uint8(lessPredictableRandom[index++])/divider;

       if(whosTurn){
         console.log("damaging bird 1",thisDamage);
         if(health1<thisDamage) {
           health1=0;
         }else{
           health1-=thisDamage;
         }
       }else{
         console.log("damaging bird 2",thisDamage);
         if(health2<thisDamage) {
           health2=0;
         }else{
           health2-=thisDamage;
         }
       }

     }

     if(health1>0){
       dodo1.wins++;
       console.log("dodo1 wins!");
     } else {
       dodo2.wins++;
       console.log("dodo2 wins!");
     }

     dodo1.available=true;
     dodo2.available=true;
  }

  function tokenURI(uint256 id) public view override returns (string memory) {
      require(_exists(id), "not exist");
      Dodo storage dodo = dodos[id];
      string memory name = string(abi.encodePacked('Dodo #',id.toString()));
      string memory description = string(abi.encodePacked('This Dodo is the color #',dodo.color.toColor()/*,' with a chubbiness of ',uint2str(chubbiness[id])*/,'!!!'));
      string memory image = Base64.encode(bytes(generateSVGofTokenById(id)));

      return
          string(
              abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                          abi.encodePacked(
                              '{"name":"',
                              name,
                              '", "description":"',
                              description,
                              /*'", "external_url":"https://burnyboys.com/token/',
                              id.toString(),
                              '", "attributes": [{"trait_type": "color", "value": "#',
                              dodo.color.toColor(),
                              '"},{"trait_type": "chubbiness", "value": ',
                              uint2str(chubbiness[id]),
                              */'", "owner":"',
                              (uint160(ownerOf(id))).toHexString(20),
                              '", "image": "',
                              'data:image/svg+xml;base64,',
                              image,
                              '"}'
                          )
                        )
                    )
              )
          );
  }

  function generateSVGofTokenById(uint256 id) internal view returns (string memory) {

    string memory svg = string(abi.encodePacked(
      '<svg width="550" height="550" xmlns="http://www.w3.org/2000/svg">',
        renderTokenById(id),
      '</svg>'
    ));

    return svg;
  }

  // Visibility is `public` to enable it being called by other contracts for composition.
  function renderTokenById(uint256 id) public view returns (string memory) {
    string memory render = string(abi.encodePacked(
      '<defs><style>.cls-1,.cls-2,.cls-3,.cls-4,.cls-5{stroke-miterlimit:10;}.cls-1,.cls-5{stroke:#0d0d0d;}.cls-2{fill:#685c48;}.cls-2,.cls-3,.cls-4{stroke:#231f20;}.cls-3{fill:#e5d67f;}.cls-4{fill:#fee78a;}.cls-5{fill:#fff;}</style></defs>',
      '<g id="rightleg"><path class="cls-3" d="M143.7,386.83v54.16l-42.75-4.92s-9.92,8.21,0,9.85,42.75,5.47,42.75,5.47l-42.75,21.88s-4.85,11.49,4.45,8.21,45.41-24.07,45.41-24.07l33.37,24.66s13.68,7.62,8.75-6.06-36.66-33.37-36.66-33.37l-1.64-74.95s-9.85-13.13-12.04-1.09,1.09,20.24,1.09,20.24Z"/><path class="cls-2" d="M134.05,321.9s-21.69,55.95,11.23,74.37c0,0,24.31,20.71,59.12-53.07l-70.35-21.3Z"/></g><g id="tailfeathers"><path class="cls-2" d="M289.16,210.59s52.14-55.13,77.62-24.25c0,0-25.37-2.23-44.02,17.76,0,0,32.43-22.99,44.02-10.34,0,0-42.1,18.06-38.81,27.33,0,0,41.9-25.48,44.22-7.72,0,0-38.24,4.75-41.51,17.05,0,0,33.02-14.61,33.79,0,0,0-31.09,2.17-33.79,16.16s-16.4,10.81-16.4,10.81l-25.11-46.8h0"/></g><g id="body"><path class="cls-2" d="M99.51,13.63s39.88-41.56,62.29,23.23c0,0-4.41,48.44-20.67,66.61,0,0-28.38,81.14,7.96,104.16,0,0,18.77,65.4-28.76,55.71,0,0-56.04-53.25-17.26-155.63l-3.55-94.08Z"/><path class="cls-2" d="M149.08,207.62s142.35-84.51,191.59,76.88c0,0,3.36,113.8-178.87,108.88,0,0-82.38-53.83-45.86-134.97,0,0,17.73-51.63,33.15-50.79Z"/></g><g id="leftleg"><path class="cls-3" d="M232.68,406.53v54.16l-42.75-4.92s-9.92,8.21,0,9.85,42.75,5.47,42.75,5.47l-42.75,21.88s-4.85,11.49,4.45,8.21,45.41-24.07,45.41-24.07l33.37,24.66s13.68,7.62,8.75-6.06-36.66-33.37-36.66-33.37l-1.64-74.95s-9.85-13.13-12.04-1.09,1.09,20.24,1.09,20.24Z"/><path class="cls-2" d="M189.93,351.82s6.67,59.64,44.37,60.73c0,0,31.14,7.11,27.85-74.41l-72.22,13.68Z"/></g><g id="righteye"><g><circle class="cls-5" cx="95.13" cy="21.31" r="20.81"/><circle class="cls-1" cx="90.88" cy="22.72" r="1.49"/></g></g><g id="bottomjaw"><path class="cls-4" d="M118.26,100.84s-68.44,9.78-85.74,.32c0,0-1.84-6.51,7.65-7.79l52.31-21.87s39.06,14.66,26.4,26.09"/></g><g id="beak"><circle class="cls-4" cx="120.21" cy="56.38" r="35.42"/><path class="cls-4" d="M90.86,36.54s-37.56,28.62-55.12,29.23c0,0-27.25-21.8-34.52,4.24,0,0-3.63,21.19,5.45,29.07h4.84s21.71-9.69,34.17-9.69c0,0,39.94-6.43,43.16-16.54"/></g><g id="lefteye"><g><circle class="cls-5" cx="117.35" cy="31.25" r="20.81"/><circle class="cls-1" cx="113.1" cy="32.66" r="1.49"/></g></g>'
      ));

    return render;
  }

  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
      if (_i == 0) {
          return "0";
      }
      uint j = _i;
      uint len;
      while (j != 0) {
          len++;
          j /= 10;
      }
      bytes memory bstr = new bytes(len);
      uint k = len;
      while (_i != 0) {
          k = k-1;
          uint8 temp = (48 + uint8(_i - _i / 10 * 10));
          bytes1 b1 = bytes1(temp);
          bstr[k] = b1;
          _i /= 10;
      }
      return string(bstr);
  }
}