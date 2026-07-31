String partyNounForCount(int count) => count == 1 ? 'Party' : 'Parties';

String partyCountLabel(int count) {
  return '$count ${partyNounForCount(count)}';
}

String partiesAheadLabel(int count) => '${partyCountLabel(count)} Ahead';
