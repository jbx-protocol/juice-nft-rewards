pragma solidity 0.8.6;

import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import 'forge-std/Test.sol';

contract TestJBTieredNFTRewardDelegate is Test {
  using stdStorage for StdStorage;

  address beneficiary = address(bytes20(keccak256('beneficiary')));
  address owner = address(bytes20(keccak256('owner')));
  address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));
  address mockJBDirectory = address(bytes20(keccak256('mockJBDirectory')));
  address mockTokenUriResolver = address(bytes20(keccak256('mockTokenUriResolver')));
  address mockTerminalAddress = address(bytes20(keccak256('mockTerminalAddress')));
  address mockJBProjects = address(bytes20(keccak256('mockJBProjects')));

  uint256 projectId = 69;

  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com/';
  string contractUri = 'ipfs://null';

  // NodeJS: function con(hash) { Buffer.from(bs58.decode(hash).slice(2)).toString('hex') }
  // JS;  0x${bs58.decode(hash).slice(2).toString('hex')})

  bytes32[] tokenUris = [
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0xf5d60fc6f462f6176982833f5e2ca222a2ced265fa94e4ce1c477d74910250ed),
    bytes32(0x4258512cfb09993d9f3613a59ffc592a5593abf3c06ed57a22656c5fbca4de23),
    bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf50434fe70ee6d8ab78f83e358c8),
    bytes32(0xae7035a8ef12433adbf4a55f2faabecff3446276fdbc6f6209e6bba25ee358c8),
    bytes32(0xae7035a8ef1242fc4b803a9284453843f278307462311f8b8b90fddfcbe358c8),
    bytes32(0xae824fb9f7de128f66cb5e224e4f8c65f37c479ee6ec7193c8741d6f997f5a18),
    bytes32(0xae7035a8f8d14617dd6d904265fe7d84a493c628385ffba7016d6463c852e8c8),
    bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf50434fe70ee6d8ab78f74adbbf7),
    bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf51c38098273db23452d955758c8)
  ];

  string[] theoricHashes = [
    'QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz',
    'QmetHutWQPz3qfu5jhTi1bqbRZXt8zAJaqqxkiJoJCX9DN',
    'QmSodj3RSrXKPy3WRFSPz8HRDVyRdrBtjxBfoiWBgtGugN',
    'Qma5atSTeoKJkcXe2R7gdmcvPvLJJkh2jd4cDZeM1wnFgK',
    'Qma5atSTeoKJkcXe2R7typcvPvLJJkh2jd4cDZeM1wnFgK',
    'Qma5atSTeoKJKSQSDFcgdmcvPvLJJkh2jd4cDZeM1wnFgK',
    'Qma5rtytgfdgzrg4345RFGdfbzert345rfgvs5YRtSTkcX',
    'Qma5atSTkcXe2R7gdmcvPvLJJkh2234234QcDZeM1wnFgK',
    'Qma5atSTeoKJkcXe2R7gdmcvPvLJJkh2jd4cDZeM1ZERze',
    'Qma5atSTeoKJkcXe2R7gdmcvPvLJLkh2jd4cDZeM1wnFgK'
  ];

  // The theoretical tokenUri is therefore http://www.null.com/QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz

  JBNFTRewardTierData[] tierData;

  JBTieredLimitedNFTRewardDataSource delegate;

  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    uint256 totalAmountContributed,
    uint256 numRewards,
    address caller
  );

  event MintReservedToken(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    address caller
  );

  event SetReservedTokenBeneficiary(
    address indexed beneficiary,
    address caller
  );

  function setUp() public {
    vm.label(beneficiary, 'beneficiary');
    vm.label(owner, 'owner');
    vm.label(reserveBeneficiary, 'reserveBeneficiary');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
    vm.label(mockTerminalAddress, 'mockTerminalAddress');
    vm.label(mockJBProjects, 'mockJBProjects');

    vm.etch(mockJBDirectory, new bytes(0x69));
    vm.etch(mockTokenUriResolver, new bytes(0x69));
    vm.etch(mockTerminalAddress, new bytes(0x69));
    vm.etch(mockJBProjects, new bytes(0x69));

    // Create 10 tiers, each with 100 tokens available to mint
    for (uint256 i; i < 10; i++) {
      tierData.push(
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(100),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[i]
        })
      );
    }

    delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );
  }

  function testJBTieredNFTRewardDelegate_tiers_returnsAllTiers(uint8 numberOfTiers) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierData[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    // Avoid having difference due to the reverse order of the tiers array in _addTierData
    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(i + 1, _tierData[i]);
    }

    assertEq(_delegate.tiers(), _tiers);
  }

  function testJBTieredNFTRewardDelegate_tier_returnsTheGivenTier(
    uint8 numberOfTiers,
    uint8 givenTier
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierData[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    // Avoid having difference due to the reverse order of the tiers array in _addTierData
    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(i + 1, _tierData[i]);
    }

    // Check: correct tier, if exist?
    if (givenTier <= numberOfTiers && givenTier != 0)
      assertEq(_delegate.tier(givenTier), _tiers[givenTier - 1]);
    else
      assertEq( // empty tier if not?
        _delegate.tier(givenTier),
        JBNFTRewardTier({id: givenTier, data: JBNFTRewardTierData(0, 0, 0, 0, 0, 0, 0)})
      );
  }

  function testJBTieredNFTRewardDelegate_totalSupply_returnsTotalSupply(uint16 numberOfTiers)
    public
  {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(100 - (i + 1)),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[0]
        })
      );
    }

    assertEq(_delegate.totalSupply(), ((numberOfTiers * (numberOfTiers + 1)) / 2));
  }

  function testJBTieredNFTRewardDelegate_balanceOf_returnsCompleteBalance(
    uint16 numberOfTiers,
    address holder
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setBalanceOf(holder, i + 1, (i + 1) * 10);
    }

    assertEq(_delegate.balanceOf(holder), 10 * ((numberOfTiers * (numberOfTiers + 1)) / 2));
  }

  function testJBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_returnsOutstandingReserved()
    public
  {
    // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reservedRate is 40% (4000/10000)
    // meaning there are 47.6 total reserved to mint (-> rounding up 48), 1 being already minted, 47 are outstanding
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: tokenUris[i]
        })
      );
      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 i; i < 10; i++)
      assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 47);
  }

  // --------
  function TOFIX_JBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_FuzzedreturnsOutstandingReserved(
    uint16 initialQuantity,
    uint16 totalMinted,
    uint16 reservedMinted,
    uint16 reservedRate
  ) public {
    vm.assume(initialQuantity > totalMinted);
    vm.assume(totalMinted > reservedMinted);
    if (reservedRate != 0)
      vm.assume(
        uint256((totalMinted - reservedMinted) * reservedRate) / JBConstants.MAX_RESERVED_RATE >=
          reservedMinted
      );

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false,
      reserveBeneficiary // _shouldMintByDefault
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: tokenUris[i]
        })
      );
      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    // No reserved token were available
    if (reservedRate == 0 || initialQuantity == 0)
      for (uint256 i; i < 10; i++)
        assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 0);
    else if (
      reservedMinted != 0 && (totalMinted * reservedRate) / JBConstants.MAX_RESERVED_RATE > 0
    )
      for (uint256 i; i < 10; i++)
        assertEq(
          _delegate.numberOfReservedTokensOutstandingFor(i + 1),
          ((totalMinted - reservedMinted * reservedRate) / JBConstants.MAX_RESERVED_RATE)
        );
  }

  function testJBTieredNFTRewardDelegate_getvotingUnits_returnsTheTotalVotingUnits(
    uint16 numberOfTiers,
    address holder
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setBalanceOf(holder, i + 1, 10);
    }

    assertEq(_delegate.getVotingUnits(holder), 10 * ((numberOfTiers * (numberOfTiers + 1)) / 2));
  }

  function testJBTieredNFTRewardDelegate_tierIdOfToken_returnsCorrectTierNumber(
    uint8 _tierId,
    uint8 _tokenNumber
  ) external {
    vm.assume(_tierId > 0 && _tokenNumber > 0);
    uint256 tokenId = _generateTokenId(_tierId, _tokenNumber);

    assertEq(delegate.tierIdOfToken(tokenId), _tierId);
  }

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfNotMinted(uint256 tokenId)
    external
  {
    // Token not minted -> no URI
    assertEq(delegate.tokenURI(tokenId), '');
  }

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfResolverUsed(
    uint256 tokenId,
    address holder
  ) external {
    vm.assume(holder != address(0));

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    // Mock the URI resolver call
    vm.mockCall(
      mockTokenUriResolver,
      abi.encodeWithSignature('getUri(uint256)', tokenId),
      abi.encode('resolverURI')
    );

    _delegate.ForTest_setOwnerOf(tokenId, holder);

    assertEq(_delegate.tokenURI(tokenId), 'resolverURI');
  }

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfNoResolverUsed(address holder)
    external
  {
    vm.assume(holder != address(0));

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    for (uint256 i; i < _tierData.length; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(address(0)),
        contractUri,
        baseUri,
        owner,
        _tierData,
        false,
        reserveBeneficiary
      );

    for (uint256 i = 1; i <= _tierData.length; i++) {
      uint256 tokenId = _generateTokenId(i, 1);

      _delegate.ForTest_setOwnerOf(tokenId, holder);

      assertEq(
        _delegate.tokenURI(tokenId),
        string(abi.encodePacked(baseUri, theoricHashes[i - 1]))
      );
    }
  }

  function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnCurrentOwnerIfFirstOwner(
    uint256 tokenId,
    address _owner
  ) public {
    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    _delegate.ForTest_setOwnerOf(tokenId, _owner);
    assertEq(_delegate.firstOwnerOf(tokenId), _owner);
  }

  function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnFirstOwnerIfOwnerChanged(
    uint256 tokenId,
    address _owner,
    address _previousOwner
  ) public {
    vm.assume(_owner != _previousOwner);
    vm.assume(_previousOwner != address(0));

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    _delegate.ForTest_setOwnerOf(tokenId, _owner);
    _delegate.ForTest_setFirstOwnerOf(tokenId, _previousOwner);

    assertEq(_delegate.firstOwnerOf(tokenId), _previousOwner);
  }

  function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnAddressZeroIfNotMinted(
    uint256 tokenId
  ) public {
    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    assertEq(_delegate.firstOwnerOf(tokenId), address(0));
  }

  function testJBTieredNFTRewardDelegate_constructor_deployIfNoEmptyInitialQuantity(uint8 nbTiers)
    public
  {
    vm.assume(nbTiers < 10);

    // Create new tiers array
    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](nbTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);

    for (uint256 i; i < nbTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80(i * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierData[i]});
    }

    JBTieredLimitedNFTRewardDataSource _delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    // Check: delegate has correct parameters?
    assertEq(_delegate.projectId(), projectId);
    assertEq(address(_delegate.directory()), mockJBDirectory);
    assertEq(_delegate.name(), name);
    assertEq(_delegate.symbol(), symbol);
    assertEq(address(_delegate.tokenUriResolver()), mockTokenUriResolver);
    assertEq(_delegate.contractUri(), contractUri);
    assertEq(_delegate.owner(), owner);
    assertEq(_delegate.tiers(), _tiers);
  }

  function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfOneEmptyInitialQuantity(
    uint8 nbTiers,
    uint8 errorIndex
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers);

    // Create new tiers array
    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](nbTiers);
    for (uint256 i; i < nbTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80(i * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    _tierData[errorIndex].initialQuantity = 0;

    // Expect the error at i+1 (as the floor is now smaller than i)
    vm.expectRevert(abi.encodeWithSignature('NO_QUANTITY()'));
    new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault,
      reserveBeneficiary
    );
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_mintReservedToken() public {
    // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reservedRate is 40% (4000/10000)
    // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;
    uint256 nbTiers = 3;

    vm.mockCall(
      mockJBProjects,
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(owner)
    );

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](nbTiers);

    // Temp tiers, will get overwritten later (pass the constructor check)
    for (uint256 i; i < nbTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < nbTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: tokenUris[i]
        })
      );

      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 tier = 1; tier <= nbTiers; tier++) {
      uint256 mintable = _delegate.numberOfReservedTokensOutstandingFor(tier);

      for (uint256 token = 1; token <= mintable; token++) {
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit MintReservedToken(
          _generateTokenId(tier, totalMinted + token),
          tier,
          reserveBeneficiary,
          owner
        );
      }

      vm.prank(owner);
      _delegate.mintReservesFor(tier, mintable);

      // Check balance
      assertEq(_delegate.balanceOf(reserveBeneficiary), mintable * tier);
    }
  }

  // Used to detect coverage
  function testJBTieredNFTRewardDelegate_setReservedTokenBeneficiary() public {
    testJBTieredNFTRewardDelegate_setReservedTokenBeneficiaryFuzzed(address(bytes20(keccak256('newReserveBeneficiary'))));
    testJBTieredNFTRewardDelegate_setReservedTokenBeneficiaryFuzzed(address(bytes20(keccak256('anotherNewReserveBeneficiary'))));
  }

  function testJBTieredNFTRewardDelegate_setReservedTokenBeneficiaryFuzzed(address _newBeneficiary) public {
    // Make sure the beneficiary is actually changing
    vm.assume(_newBeneficiary != delegate.reservedTokenBeneficiary());

    vm.expectEmit(true, true, true, true, address(delegate));
    emit SetReservedTokenBeneficiary(_newBeneficiary, owner);

    vm.prank(owner);
    delegate.setReservedTokenBeneficiary(_newBeneficiary);

    assertEq(delegate.reservedTokenBeneficiary(), _newBeneficiary);
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfNotEnoughReservedLeft() public {
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault,
      reserveBeneficiary
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: tokenUris[i]
        })
      );

      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 i = 1; i <= 10; i++) {
      // Get the amount that we can mint successfully
      uint256 amount = _delegate.numberOfReservedTokensOutstandingFor(i);
      // Increase it by 1 to cause an error
      amount++;

      vm.expectRevert(abi.encodeWithSignature('INSUFFICIENT_RESERVES()'));
      vm.prank(owner);
      _delegate.mintReservesFor(i, amount);
    }
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToAdd
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers < 30);
    vm.assume(numberTiersToAdd > 0);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierData[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    JBNFTRewardTierData[] memory _tierDataToAdd = new JBNFTRewardTierData[](numberTiersToAdd);
    JBNFTRewardTier[] memory _tiersAdded = new JBNFTRewardTier[](numberTiersToAdd);

    for (uint256 i; i < numberTiersToAdd; i++) {
      _tierDataToAdd[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 100),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiersAdded[i] = JBNFTRewardTier({id: _tiers.length + (i + 1), data: _tierDataToAdd[i]});
    }

    vm.prank(owner);
    _delegate.adjustTiers(_tierDataToAdd, new uint256[](0));

    JBNFTRewardTier[] memory _storedTiers = _delegate.tiers();

    // Check: Expected number of tiers?
    assertEq(_storedTiers.length, _tiers.length + _tiersAdded.length);

    // Check: Are all tiers in the new tiers (unsorted)?
    assertTrue(_isIn(_tiers, _storedTiers));
    assertTrue(_isIn(_tiersAdded, _storedTiers));
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_removeTiers(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToRemove
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers > 0 && initialNumberOfTiers < 30);
    vm.assume(numberTiersToRemove > 0 && numberTiersToRemove < initialNumberOfTiers);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierData[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    uint256[] memory _tiersToRemove = new uint256[](numberTiersToRemove);

    JBNFTRewardTierData[] memory _tierDataRemaining = new JBNFTRewardTierData[](
      initialNumberOfTiers - numberTiersToRemove + 1
    );
    JBNFTRewardTier[] memory _tiersRemaining = new JBNFTRewardTier[](
      initialNumberOfTiers - numberTiersToRemove + 1
    );

    for (uint256 i; i < initialNumberOfTiers; i++) {
      if (i >= numberTiersToRemove) {
        uint256 _arrayIndex = i - numberTiersToRemove;
        _tierDataRemaining[_arrayIndex] = JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(100),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          tokenUri: tokenUris[0]
        });

        _tiersRemaining[_arrayIndex] = JBNFTRewardTier({
          id: i + 1,
          data: _tierDataRemaining[_arrayIndex]
        });

      } else _tiersToRemove[i] = i + 1;
    }

    vm.prank(owner);
    _delegate.adjustTiers(new JBNFTRewardTierData[](0), _tiersToRemove);

    JBNFTRewardTier[] memory _storedTiers = _delegate.tiers();

    // TODO: Check Expected number of tiers?
    // assertEq(_storedTiers.length, _tiers.length - numberTiersToRemove);

    // Check that all the remaining tiers still exist
    assertTrue(_isIn(_tiersRemaining, _storedTiers));

    // Check that none of the removed tiers still exist
    for (uint256 i; i < _tiersToRemove.length; i++) {
      JBNFTRewardTier[] memory _removedTier = new JBNFTRewardTier[](1);
      _removedTier[0] = _tiers[i];
      assertTrue(!_isIn(_removedTier, _storedTiers));
    }
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_revertIfAddingWithVotingPower(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToAdd
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers < 30);
    vm.assume(numberTiersToAdd > 0);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierData[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    JBNFTRewardTierData[] memory _tierDataToAdd = new JBNFTRewardTierData[](numberTiersToAdd);
    JBNFTRewardTier[] memory _tiersAdded = new JBNFTRewardTier[](numberTiersToAdd);

    for (uint256 i; i < numberTiersToAdd; i++) {
      _tierDataToAdd[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 100),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiersAdded[i] = JBNFTRewardTier({id: _tiers.length + (i + 1), data: _tierDataToAdd[i]});
    }

    vm.expectRevert(abi.encodeWithSignature('VOTING_UNITS_NOT_ALLOWED()'));
    vm.prank(owner);
    _delegate.adjustTiers(_tierDataToAdd, new uint256[](0));
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_revertIfEmptyQuantity(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToAdd
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers < 30);
    vm.assume(numberTiersToAdd > 0);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierData[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    JBNFTRewardTierData[] memory _tierDataToAdd = new JBNFTRewardTierData[](numberTiersToAdd);
    JBNFTRewardTier[] memory _tiersAdded = new JBNFTRewardTier[](numberTiersToAdd);

    for (uint256 i; i < numberTiersToAdd; i++) {
      _tierDataToAdd[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 100),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(0),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiersAdded[i] = JBNFTRewardTier({id: _tiers.length + (i + 1), data: _tierDataToAdd[i]});
    }

    vm.expectRevert(abi.encodeWithSignature('NO_QUANTITY()'));
    vm.prank(owner);
    _delegate.adjustTiers(_tierDataToAdd, new uint256[](0));
  }

  // -- delegate actions --

  // If the amount payed is below the contributionFloor to receive an NFT the pay should not revert
  function testJBTieredNFTRewardDelegate_didPay_doesNotRevertOnAmountBelowContributionFloor()
    external
  {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    // The calldata is correct but the 'msg.sender' is not the '_expectedCaller'
    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(JBTokens.ETH, tierData[0].contributionFloor - 1, 0, 0), // 1 wei below the minimum amount
        0,
        msg.sender,
        false,
        '',
        new bytes(0)
      )
    );

    // Make sure no new NFT was minted
    assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  function testJBTieredNFTRewardDelegate_didPay_revertIfAllowanceRunsOutInParticularTier()
    external
  {
    // Create 10 tiers, each with 10 tokens available to mint
    for (uint256 i; i < 10; i++) {
      tierData.push(
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(10),
          initialQuantity: uint40(10),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[i]
        })
      );
    }

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _supplyLeft = tierData[0].initialQuantity;
    while (true) {
      uint256 _totalSupplyBeforePay = delegate.totalSupply();

      // If there is no supply left this should revert
      if (_supplyLeft == 0) {
        vm.expectRevert(abi.encodeWithSignature('OUT()'));
      }

      uint8[] memory tierSelected = new uint8[](1);
      tierSelected[0] = 1;

      bytes memory _metadata = abi.encode(bytes32(0), tierSelected);

      // Perform the pay
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, tierData[0].contributionFloor, 0, 0),
          0,
          msg.sender,
          false,
          '',
          abi.encode(_metadata)
        )
      );

      // Make sure if there was no supply left there was no NFT minted
      if (_supplyLeft == 0) {
        assertEq(delegate.totalSupply(), _totalSupplyBeforePay);
        break;
      } else {
        assertEq(delegate.totalSupply(), _totalSupplyBeforePay + 1);
      }

      --_supplyLeft;
    }
  }

  function testJBTieredNFTRewardDelegate_didPay_revertIfCallerIsNotATerminalOfProjectId(
    address _terminal
  ) external {
    vm.assume(_terminal != mockTerminalAddress);

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, _terminal),
      abi.encode(false)
    );

    // The caller is the _expectedCaller however the terminal in the calldata is not correct
    vm.prank(_terminal);
    vm.expectRevert(abi.encodeWithSignature('INVALID_PAYMENT_EVENT()'));
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(address(0), 0, 0, 0),
        0,
        msg.sender,
        false,
        '',
        new bytes(0)
      )
    );
  }

  function testJBTieredNFTRewardDelegate_didPay_doNotMintIfNotUsingCorrectToken(address token)
    external
  {
    vm.assume(token != delegate.contributionToken());

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    // The caller is the _expectedCaller however the terminal in the calldata is not correct
    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(token, 0, 0, 0),
        0,
        msg.sender,
        false,
        '',
        new bytes(0)
      )
    );

    // Check: nothing has been minted
    assertEq(delegate.totalSupply(), 0);
  }

  // ----------------
  // Internal helpers
  // ----------------

  // JBNFTRewardTier comparison
  function assertEq(JBNFTRewardTier memory first, JBNFTRewardTier memory second) private {
    assertEq(first.id, second.id);
    assertEq(first.data.contributionFloor, second.data.contributionFloor);
    assertEq(first.data.lockedUntil, second.data.lockedUntil);
    assertEq(first.data.remainingQuantity, second.data.remainingQuantity);
    assertEq(first.data.initialQuantity, second.data.initialQuantity);
    assertEq(first.data.votingUnits, second.data.votingUnits);
    assertEq(first.data.reservedRate, second.data.reservedRate);
    assertEq(first.data.tokenUri, second.data.tokenUri);
  }

  // JBNFTRewardTier Array comparison
  function assertEq(JBNFTRewardTier[] memory first, JBNFTRewardTier[] memory second) private {
    assertEq(first.length, second.length);

    for (uint256 i; i < first.length; i++) {
      assertEq(first[i].id, second[i].id);
      assertEq(first[i].data.contributionFloor, second[i].data.contributionFloor);
      assertEq(first[i].data.lockedUntil, second[i].data.lockedUntil);
      assertEq(first[i].data.remainingQuantity, second[i].data.remainingQuantity);
      assertEq(first[i].data.initialQuantity, second[i].data.initialQuantity);
      assertEq(first[i].data.votingUnits, second[i].data.votingUnits);
      assertEq(first[i].data.reservedRate, second[i].data.reservedRate);
      assertEq(first[i].data.tokenUri, second[i].data.tokenUri);
    }
  }

  // Generate tokenId's based on token number and tier
  function _generateTokenId(uint256 _tierId, uint256 _tokenNumber)
    internal
    pure
    returns (uint256 tokenId)
  {
    // The tier ID in the first 8 bits.
    tokenId = _tierId;

    // The token number in the rest.
    tokenId |= _tokenNumber << 8;
  }

  // Check if every elements from smol are in bigg
  function _isIn(JBNFTRewardTier[] memory smol, JBNFTRewardTier[] memory bigg)
    private
    pure
    returns (bool)
  {
    // Cannot be oversized
    if (smol.length > bigg.length) return false;

    if (smol.length == 0) return true;

    uint256 count;
    for (uint256 smolIter; smolIter < smol.length; smolIter++) {
      for (uint256 biggIter; biggIter < bigg.length; biggIter++) {
        if (_compareTiers(smol[smolIter], bigg[biggIter])) {
          count += smolIter + 1; // 1-indexed, as the length
          break;
        }
      }
    }

    // (smoll.length)!
    return count == (smol.length * (smol.length + 1)) / 2;
  }

  function _compareTiers(JBNFTRewardTier memory first, JBNFTRewardTier memory second)
    private
    pure
    returns (bool)
  {
    return (first.id == second.id &&
      first.data.contributionFloor == second.data.contributionFloor &&
      first.data.lockedUntil == second.data.lockedUntil &&
      first.data.remainingQuantity == second.data.remainingQuantity &&
      first.data.initialQuantity == second.data.initialQuantity &&
      first.data.votingUnits == second.data.votingUnits &&
      first.data.reservedRate == second.data.reservedRate &&
      first.data.tokenUri == second.data.tokenUri);
  }
}

// ForTest to manually set some internalt nested values
contract ForTest_JBTieredLimitedNFTRewardDataSource is JBTieredLimitedNFTRewardDataSource {
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    string memory _baseUri,
    address _owner,
    JBNFTRewardTierData[] memory _tierData,
    bool _shouldMintByDefault,
    address _reserveBeneficiary
  )
    JBTieredLimitedNFTRewardDataSource(
      _projectId,
      _directory,
      _name,
      _symbol,
      _tokenUriResolver,
      _contractUri,
      _baseUri,
      _owner,
      _tierData,
      _shouldMintByDefault,
      _reserveBeneficiary
    )
  {}

  function ForTest_setTier(uint256 index, JBNFTRewardTierData calldata newTier) public {
    tierData[index] = newTier;
  }

  function ForTest_setBalanceOf(
    address holder,
    uint256 tier,
    uint256 balance
  ) public {
    tierBalanceOf[holder][tier] = balance;
  }

  function ForTest_setReservesMintedFor(uint256 tier, uint256 amount) public {
    numberOfReservesMintedFor[tier] = amount;
  }

  function ForTest_setOwnerOf(uint256 tokenId, address _owner) public {
    _owners[tokenId] = _owner;
  }

  function ForTest_setFirstOwnerOf(uint256 tokenId, address _owner) public {
    _firstOwnerOf[tokenId] = _owner;
  }
}
