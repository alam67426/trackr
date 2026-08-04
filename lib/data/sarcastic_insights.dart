/// Light, local-only copy for Trackr's educational insight cards. The app
/// keeps calculations factual; only the presentation gets a friendly roast.
class SarcasticInsights {
  static String latestExpense({
    required String category,
    required String amount,
    required int seed,
  }) {
    final label = category.replaceAll('_', ' ');
    final messages = [
      '$amount just left for $label. Wallet has filed a tiny complaint. 💸',
      'Fresh $label spend: $amount. Budget is pretending not to notice. 👀',
      '$amount on $label logged. The receipt has joined the money memoir. 🧾',
      '$label claimed $amount. Trackr caught it before it could disappear into vibes. 🎯',
    ];
    return _pick(messages, seed);
  }

  static String latestIncome({
    required String source,
    required String amount,
    required int seed,
  }) {
    final label = source.isEmpty ? 'income' : source;
    final messages = [
      '$amount arrived from $label. Bank balance has entered its optimistic era. ✨',
      'Income alert: $amount from $label. The budget can breathe for a minute. 😌',
      '$amount credited from $label. Future-you has been briefly reassured. 🙌',
      'Money in: $amount from $label. Spend it with a plan, not a plot twist. 🎬',
      'Aaj kamaoge to kal araam se baithoge. Mehnat par bharosa rakho. 💪',
      'Aamdani aathanni, kharcha rupaiya? Aaj se Trackr is equation ko watch karega. 👀',
    ];
    return _pick(messages, seed);
  }

  static String categoryShare(String category, double share, int seed) {
    final percent = (share * 100).round();
    final messages = switch (category) {
      'shopping' => percent >= 60
          ? [
              'Bhai, Amazon ka warehouse ghar ke paas shift ho gaya kya? $percent% shopping! 📦',
              'Shopping cart full, bank balance emotional. $percent% went shopping! 🛍️',
              'Flipkart CEO is quietly grateful for your $percent% contribution. 🏆',
            ]
          : [
              'Shopping is $percent% of expenses. Cart ko thoda meditation karao. 🛒',
              '$percent% shopping: responsible adult mode is loading... slowly. 😄',
              'Your wardrobe is thriving. The budget would like a word. 👗',
            ],
      'food' || 'dining' => percent >= 40
          ? [
              'Kitchen ka rent bhi de rahe ho, ya sirf Swiggy ka? $percent% food spend! 🍕',
              'Zomato knows your address better than your relatives. $percent% food! 🍔',
              'Food budget is giving restaurant-owner energy at $percent%. 🍜',
            ]
          : [
              '$percent% on food. Taste buds aur budget dono somehow alive hain. 🌶️',
              'Food is $percent% of expenses. Maggi occasionally deserves a cameo. 🍜',
            ],
      'entertainment' || 'subscriptions' => const [
          'Netflix and chill? More like Netflix and bill. 📺',
          'Your subscriptions are having a better social life than the budget. 🍿',
          'Entertainment spend detected. At least the plot twist was worth it? 🎬',
        ],
      'commute' || 'travel' || 'fuel' => const [
          'Ola, Uber, Rapido, Metro: everyone is enjoying the commute budget. 🚕',
          'Transport spend is up. GPS knows your routine; Trackr knows the bill. 🗺️',
          'Commute budget says: pedal optional, review mandatory. 🚇',
        ],
      'healthcare' => const [
          'Health comes first. Receipts come right after, apparently. 🏥',
          'Healthcare spend noted. Budget can wait; take care of yourself first. 💊',
        ],
      _ => [
          '$percent% of expenses landed here. Paisa has entered its mystery era. 🕵️',
          'This category took $percent% of the month. Trackr is taking notes. 👀',
        ],
    };
    return _pick(messages, seed);
  }

  static String savings(double rate, int seed) {
    if (rate < 0) {
      return _pick(const [
        'Expenses beat income this month. Budget is doing cardio; give it a breather. 💸',
        'Negative savings unlocked. Time for a calm look at fixed costs, not panic mode. 😅',
        'Aamdani aathanni aur kharcha rupaiya ka scene hai. Chalo, numbers ko seedha karte hain. 🧮',
      ], seed);
    }
    if (rate < .10) {
      return _pick(const [
        'Savings are playing hide-and-seek. Even a small automatic transfer counts. 🪙',
        'Bank balance is in survival mode. Start tiny; ₹100 is still a beginning. 💡',
        'Mehnat ka paisa hai, thoda future-you ke naam bhi side mein rakho. 🌱',
      ], seed);
    }
    if (rate < .20) {
      return _pick(const [
        'Savings exist, which is already better than vibes-only finance. Keep nudging it up. 🌱',
        'Not bad. Your future self has received a small but meaningful apology. 🙌',
      ], seed);
    }
    return _pick(const [
      'Savings look strong. Warren Buffett has not called yet, but he may be curious. 🤑',
      'Future-you is quietly impressed. Present-you may celebrate with a sensible chai. ☕',
      'Savings rate is healthy. Responsible adult badge: temporarily unlocked. 🏅',
    ], seed);
  }

  static String budget(String category, double ratio, int seed) {
    final name = category.replaceAll('_', ' ');
    if (ratio >= 1) {
      return _pick([
        '$name budget has left the chat. Time for a tiny spending timeout. 🛑',
        'Budget exceeded for $name. The category chose chaos today. ⚠️',
        '$name is over budget. Trackr is not angry, just dramatically concerned. 😮',
      ], seed);
    }
    return _pick([
      '$name is at ${(ratio * 100).round()}%. Budget ka last warning samjho. ⚠️',
      'Careful: $name has used most of its budget. Chai without add-ons for a bit? ☕',
      '$name is close to the limit. Wallet says: bas, boss. 🧾',
    ], seed);
  }

  static String investment(int count, int seed) => _pick(
        count == 0
            ? const [
                'Investing ka “right time” calendar invite abhi tak nahi aaya. Learn first, then start small. 📈',
                'Emergency buffer first, fancy investment app later. Boring, but effective. 🛟',
              ]
            : const [
                'Portfolio spotted. Diversification is not just collecting app screenshots. 📊',
                'Investment entries noted. Goal, timeline, risk, fees: the four amigos still matter. 📈',
              ],
        seed,
      );

  static String general(int seed) => _pick(const [
        'Trackr is watching the spends so future-you does not have to guess. 👀',
        'New month, new opportunity to impress the budget. Or at least not surprise it. 🎯',
        'Money came, money went, Trackr wrote it down. Professional gossip, locally stored. 📝',
        'Your wallet has a story. This month has plot twists. 🎬',
        'Small expenses are tiny until they form a group chat. Review them weekly. 💬',
        'Paisa aaj kamao, kal sukoon se khao. Bas beech mein budget ko bhi invite kar lena. 😄',
        'Dil se kharch karo, par Trackr ko bata ke. Surprise bills ka genre over-rated hai. 🎭',
        'Aamdani aur kharcha dono ki dosti zaroori hai. Warna wallet awkward ho jata hai. 🤝',
      ], seed);

  static String _pick(List<String> options, int seed) =>
      options[seed.abs() % options.length];
}
