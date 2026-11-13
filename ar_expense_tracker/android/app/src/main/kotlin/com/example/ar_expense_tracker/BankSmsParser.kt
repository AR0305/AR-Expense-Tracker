package com.example.ar_expense_tracker

import java.util.Locale

/**
 * Deterministic parser for Indian bank debit SMS (UPI, IMPS/NEFT, debit & credit card spends, ATM).
 *
 * Pure Kotlin (no Android APIs) so it can be unit-tested on the JVM.
 *
 * Accepts an SMS only when ALL of these hold:
 *  - sender is an alphanumeric DLT header (e.g. `AX-AXISBK-S`, `JD-BOBTXN`), never a phone number
 *  - it is not an OTP / failed / reversed / upcoming-debit / collect-request message
 *  - a debit marker appears before any credit marker (BoB: "Dr. from A/C ... and Cr. to <payee>")
 *  - it mentions an account, card or UPI, and has a parsable amount
 */
object BankSmsParser {

    data class ParsedBankSms(
        val amount: Double,
        val payee: String,
        val reference: String?,
        val bankName: String,
        val accountTail: String?,
        val channel: String,
        /** Payee UPI address when the SMS contains one, e.g. "q823930346@ybl". */
        val vpa: String? = null
    )

    /** DLT header fragment -> bank display name. Unknown bank headers are still parsed generically. */
    private val BANK_HEADERS: List<Pair<String, String>> = listOf(
        "AXISBK" to "Axis Bank", "AXISBN" to "Axis Bank",
        "BOBTXN" to "Bank of Baroda", "BOBSMS" to "Bank of Baroda", "BARODA" to "Bank of Baroda", "BOBCRD" to "BoB Card",
        "CANBNK" to "Canara Bank", "CNRBNK" to "Canara Bank", "CANARA" to "Canara Bank",
        "SBIUPI" to "SBI", "SBIINB" to "SBI", "SBIPSG" to "SBI", "ATMSBI" to "SBI", "CBSSBI" to "SBI", "SBICRD" to "SBI Card", "SBMSMS" to "SBI",
        "HDFCBK" to "HDFC Bank", "HDFCBN" to "HDFC Bank",
        "ICICIB" to "ICICI Bank", "ICICIT" to "ICICI Bank", "ICICIO" to "ICICI Bank",
        "KOTAKB" to "Kotak Bank", "KOTAK" to "Kotak Bank",
        "PNBSMS" to "PNB", "PUNBNK" to "PNB",
        "UNIONB" to "Union Bank", "UBOI" to "Union Bank",
        "BOIIND" to "Bank of India", "BOISMS" to "Bank of India",
        "INDBNK" to "Indian Bank", "INDIAN" to "Indian Bank",
        "CENTBK" to "Central Bank", "CBOI" to "Central Bank",
        "IOBCHN" to "Indian Overseas Bank", "IOBANK" to "Indian Overseas Bank",
        "UCOBNK" to "UCO Bank", "MAHABK" to "Bank of Maharashtra", "PSBANK" to "Punjab & Sind Bank",
        "IDFCFB" to "IDFC FIRST Bank", "INDUSB" to "IndusInd Bank", "YESBNK" to "YES Bank",
        "FEDBNK" to "Federal Bank", "RBLBNK" to "RBL Bank", "AUBANK" to "AU Bank", "IDBIBK" to "IDBI Bank",
        "BDNSMS" to "Bandhan Bank", "BANDHN" to "Bandhan Bank", "SIBSMS" to "South Indian Bank",
        "KBLBNK" to "Karnataka Bank", "KVBANK" to "Karur Vysya Bank", "CUBLTD" to "City Union Bank",
        "JKBANK" to "J&K Bank", "TMBANK" to "TMB", "DCBBNK" to "DCB Bank", "DBSBNK" to "DBS Bank",
        "SCBANK" to "Standard Chartered", "HSBCIN" to "HSBC", "CITIBK" to "Citi",
        "EQUTAS" to "Equitas Bank", "UJJIVN" to "Ujjivan Bank", "ESAFBK" to "ESAF Bank", "SURYOD" to "Suryoday Bank",
        "PAYTMB" to "Paytm Payments Bank", "AIRBNK" to "Airtel Payments Bank", "IPPBNK" to "India Post Payments Bank",
        "JIOPBK" to "Jio Payments Bank", "FINOBK" to "Fino Bank", "NSDLPB" to "NSDL Payments Bank",
        "AMEXIN" to "Amex", "ONECRD" to "OneCard", "SLICEI" to "slice"
    )

    private val EXCLUDE_PHRASES = listOf(
        "otp", "one time password", "verification code",
        "will be debited", "to be debited", "would be debited", "shall be debited", "is due", "due on", "due date",
        "has requested", "requested money", "collect request", "payment request",
        "failed", "declined", "unsuccessful", "reversed", "reversal", "refund", "could not be",
        "mandate created", "mandate registered", "mandate is set", "autopay set", "e-mandate registration",
        "pre-approved", "preapproved", "loan offer", "apply now", "click here to apply"
    )

    // Debit markers. Order in text decides debit vs credit when both appear.
    private val DEBIT_REGEX = Regex(
        "\\b(debited|debit of|debit for|dr\\.?|sent|spent|paid|withdrawn|withdrawal|purchase|txn of|transaction of)\\b",
        RegexOption.IGNORE_CASE
    )
    private val CREDIT_REGEX = Regex(
        "\\b(credited|cr\\.?|received|deposited)\\b",
        RegexOption.IGNORE_CASE
    )
    private val ACCOUNT_REGEX = Regex(
        "\\b(a/c|a/c\\.|ac|acct|account|card|upi|vpa|imps|neft|rtgs)\\b",
        RegexOption.IGNORE_CASE
    )

    private val CURRENCY_AMOUNT = Regex(
        "(?:\\brs\\.?|\\binr|₹)\\s*:?\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
        RegexOption.IGNORE_CASE
    )
    // SBI style: "debited by 150.0" with no currency symbol
    private val BARE_DEBIT_AMOUNT = Regex(
        "debited\\s+(?:by|for|with)\\s+([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
        RegexOption.IGNORE_CASE
    )

    private val REF_PATTERNS = listOf(
        Regex("upi/p2[am]/([0-9]{9,16})", RegexOption.IGNORE_CASE),
        Regex("(?:upi\\s*ref(?:erence)?\\s*(?:no\\.?|number|id)?|ref(?:erence)?\\s*(?:no\\.?|number|id)?|refno|rrn|utr(?:\\s*no\\.?)?|txn\\s*(?:id|no\\.?)|transaction\\s*id)\\s*[:.#-]?\\s*([0-9]{9,16})", RegexOption.IGNORE_CASE),
        Regex("\\bupi\\s*[:/-]?\\s*([0-9]{12})\\b", RegexOption.IGNORE_CASE)
    )

    private val ACCOUNT_TAIL = Regex(
        "(?:a/c|ac|acct|account|card)\\s*(?:no\\.?|number|ending(?:\\s+with)?)?\\s*[:.]?\\s*[x*]+\\s*([0-9]{3,6})",
        RegexOption.IGNORE_CASE
    )

    private val VPA = Regex("\\b([a-z0-9][a-z0-9._-]{1,}@[a-z][a-z0-9]{1,})\\b", RegexOption.IGNORE_CASE)

    // Payee patterns, tried in order. Each captures the payee in group 1.
    private val PAYEE_PATTERNS = listOf(
        // Axis: "UPI/P2M/631753261776/INDSTOCKS PRIVATE L"
        Regex("upi/p2[am]/[0-9]+/([^/\\n]+)", RegexOption.IGNORE_CASE),
        // ICICI: "debited for Rs 150.00 on 13-Nov-26; SWIGGY credited."
        Regex(";\\s*([A-Za-z][A-Za-z0-9 .&'_-]{1,40}?)\\s+credited", RegexOption.IGNORE_CASE),
        // HDFC / old style: "Info: UPI-SWIGGY-..." or "Info:VPS*SWIGGY"
        Regex("\\binfo\\s*[:-]\\s*(?:upi[-/])?([A-Za-z][A-Za-z0-9 .&'*_-]{1,40}?)(?:[-/]|\\.\\s|\\n|$)", RegexOption.IGNORE_CASE),
        // Card: "spent ... at SWIGGY on 13-Nov"
        Regex("\\bat\\s+([A-Za-z0-9][A-Za-z0-9 .&'*_-]{1,40}?)(?:\\s+on\\b|\\s+ref|[.;,\\n]|$)", RegexOption.IGNORE_CASE),
        // Generic: "to RADHA J;" / "trf to SWIGGY Refno" / "To SWIGGY\nOn 13/11/26"
        Regex("\\b(?:to|towards|for)\\s+([A-Za-z][A-Za-z0-9 .&'_-]{1,40}?)(?:\\s+on\\b|\\s+ref|\\s+upi|\\s+via|\\s+using|\\s+avl|\\s+bal|[.;,\\n(]|$)", RegexOption.IGNORE_CASE)
    )

    private val PAYEE_STOPWORDS = setOf(
        "your", "you", "a/c", "ac", "account", "acct", "the", "call", "block", "report", "sms", "mobile",
        "bank", "beneficiary", "self", "upi", "dispute", "rs", "inr", "avoid"
    )

    /** True when [sender] looks like a DLT bank/service header rather than a phone number. */
    fun isServiceSender(sender: String): Boolean {
        val s = sender.trim()
        if (s.isEmpty()) return false
        val digits = s.count { it.isDigit() }
        return s.any { it.isLetter() } && digits <= 2
    }

    fun bankNameFor(sender: String): String? {
        val up = sender.uppercase(Locale.ROOT)
        return BANK_HEADERS.firstOrNull { up.contains(it.first) }?.second
    }

    fun parse(sender: String, body: String): ParsedBankSms? {
        if (!isServiceSender(sender)) return null
        val text = body.replace('\u00A0', ' ').trim()
        if (text.isEmpty()) return null
        val lower = text.lowercase(Locale.ROOT)

        if (EXCLUDE_PHRASES.any { lower.contains(it) }) return null

        val debit = DEBIT_REGEX.find(text) ?: return null
        val credit = CREDIT_REGEX.find(text)
        if (credit != null && credit.range.first < debit.range.first) return null

        if (!ACCOUNT_REGEX.containsMatchIn(text)) return null

        val amount = extractAmount(text) ?: return null
        if (amount <= 0.0) return null

        // Payee search ignores the fraud-help tail ("Not you? SMS BLOCKUPI ... to 9199...")
        val core = cutHelpTail(text)

        val channel = when {
            Regex("\\b(withdrawn|withdrawal|atm)\\b", RegexOption.IGNORE_CASE).containsMatchIn(core) -> "ATM"
            Regex("\\bcard\\b", RegexOption.IGNORE_CASE).containsMatchIn(core) &&
                !Regex("\\bupi\\b", RegexOption.IGNORE_CASE).containsMatchIn(core) -> "Card"
            Regex("\\b(neft|imps|rtgs)\\b", RegexOption.IGNORE_CASE).containsMatchIn(core) -> "Bank Transfer"
            else -> "UPI"
        }

        val bankName = bankNameFor(sender) ?: "Bank"
        val payee = when (channel) {
            "ATM" -> "ATM Withdrawal"
            else -> extractPayee(core) ?: "$bankName ${if (channel == "UPI") "UPI" else channel} Payment"
        }

        return ParsedBankSms(
            amount = amount,
            payee = payee,
            reference = extractReference(text),
            bankName = bankName,
            accountTail = ACCOUNT_TAIL.find(text)?.groupValues?.get(1),
            channel = channel,
            vpa = VPA.find(core)?.groupValues?.get(1)?.lowercase(Locale.ROOT)
        )
    }

    private fun extractAmount(text: String): Double? {
        for (m in CURRENCY_AMOUNT.findAll(text)) {
            val before = text.substring(maxOf(0, m.range.first - 14), m.range.first).lowercase(Locale.ROOT)
            if (before.contains("bal") || before.contains("limit") || before.contains("lmt")) continue
            return m.groupValues[1].replace(",", "").toDoubleOrNull()
        }
        return BARE_DEBIT_AMOUNT.find(text)?.groupValues?.get(1)?.replace(",", "")?.toDoubleOrNull()
    }

    private fun extractReference(text: String): String? {
        for (p in REF_PATTERNS) {
            val m = p.find(text) ?: continue
            return m.groupValues[1]
        }
        return null
    }

    private fun cutHelpTail(text: String): String {
        val lower = text.lowercase(Locale.ROOT)
        val markers = listOf("not you", "not u?", "not u ", "if not", "not done by you", "not initiated by you", "to report", "call 1800")
        val cut = markers.map { lower.indexOf(it) }.filter { it > 0 }.minOrNull() ?: return text
        return text.substring(0, cut)
    }

    private fun extractPayee(core: String): String? {
        VPA.find(core)?.let { m ->
            val vpa = m.groupValues[1]
            return cleanVpa(vpa)
        }
        for (p in PAYEE_PATTERNS) {
            // Retry from every match start (not match end): "towards UPI payment to TEA STALL" must
            // still reach "to TEA STALL" after rejecting "UPI payment ..."
            var start = 0
            while (start < core.length) {
                val m = p.find(core, start) ?: break
                cleanName(m.groupValues[1])?.let { return it }
                start = m.range.first + 1
            }
        }
        return null
    }

    /** "swiggy@icici" -> "Swiggy"; opaque merchant QR handles ("q823930346@ybl") stay as the VPA. */
    private fun cleanVpa(vpa: String): String {
        val local = vpa.substringBefore('@')
        val letters = local.count { it.isLetter() }
        val digits = local.count { it.isDigit() }
        if (letters < 3 || digits > letters) return vpa.lowercase(Locale.ROOT)
        val words = local.split('.', '_', '-').filter { w -> w.isNotBlank() && w.any { it.isLetter() } }
        if (words.isEmpty()) return vpa.lowercase(Locale.ROOT)
        return titleCase(words.joinToString(" ")).take(40)
    }

    private fun cleanName(raw: String): String? {
        var s = raw.replace(Regex("\\s+"), " ").trim().trim('.', '-', '_', '*', '/', ' ')
        if (s.length < 2) return null
        val firstWord = s.substringBefore(' ').lowercase(Locale.ROOT)
        if (firstWord in PAYEE_STOPWORDS) return null
        if (s.count { it.isDigit() } > s.count { it.isLetter() }) return null
        s = s.replace(Regex("(?i)^(mr|mrs|ms|m/s)\\.?\\s+"), "")
        return titleCase(s).take(40)
    }

    private fun titleCase(s: String): String {
        val isAllCaps = s.none { it.isLowerCase() }
        val isAllLower = s.none { it.isUpperCase() }
        if (!isAllCaps && !isAllLower) return s
        return s.lowercase(Locale.ROOT).split(' ').joinToString(" ") { w ->
            w.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() }
        }
    }
}
