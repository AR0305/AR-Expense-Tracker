package com.example.ar_expense_tracker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class BankSmsParserTest {

    private fun parse(sender: String, body: String) = BankSmsParser.parse(sender, body)

    // ------------------------------------------------------------ real samples (user's banks)

    @Test
    fun axisUpiP2m() {
        val r = parse(
            "AX-AXISBK-S",
            "INR 1.00 debited\nA/c no. XX0217\n13-11-26, 00:17:01\nUPI/P2M/631753261776/INDSTOCKS PRIVATE L\n" +
                "Not you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank"
        )
        assertNotNull(r); r!!
        assertEquals(1.0, r.amount, 0.001)
        assertEquals("Indstocks Private L", r.payee)
        assertEquals("631753261776", r.reference)
        assertEquals("Axis Bank", r.bankName)
        assertEquals("0217", r.accountTail)
        assertEquals("UPI", r.channel)
    }

    @Test
    fun bankOfBarodaDrCr() {
        val r = parse(
            "JD-BOBTXN-S",
            "Rs.70.00 Dr. from A/C XXXXXX1444 and Cr. to q823930346@ybl. Ref:631649318288. " +
                "AvlBal:Rs3246.15(2026:11:12 07:24:34). Not you? Call 18005700/5000-BOB"
        )
        assertNotNull(r); r!!
        assertEquals(70.0, r.amount, 0.001)
        assertEquals("q823930346@ybl", r.payee)
        assertEquals("q823930346@ybl", r.vpa)
        assertEquals("631649318288", r.reference)
        assertEquals("Bank of Baroda", r.bankName)
        assertEquals("1444", r.accountTail)
    }

    @Test
    fun canaraUpi() {
        val r = parse(
            "VM-CANBNK-S",
            "Dear Customer, Acct XXX797 Dr. INR 10.00 on 07/11/26 to RADHA J; UPI: 667767449980; " +
                "Bal INR 7,063.48.Not you?SMS BLOCKUPI to 9901771222-CanaraBank"
        )
        assertNotNull(r); r!!
        assertEquals(10.0, r.amount, 0.001)
        assertEquals("Radha J", r.payee)
        assertNull(r.vpa)
        assertEquals("667767449980", r.reference)
        assertEquals("Canara Bank", r.bankName)
        assertEquals("797", r.accountTail)
    }

    // ------------------------------------------------------------ other common Indian bank formats

    @Test
    fun sbiDebitedByNoCurrency() {
        val r = parse(
            "AD-SBIUPI-S",
            "Dear UPI user A/C X1234 debited by 150.0 on date 13Nov26 trf to SWIGGY Refno 432112345678. " +
                "If not u? call 1800111109. -SBI"
        )
        assertNotNull(r); r!!
        assertEquals(150.0, r.amount, 0.001)
        assertEquals("Swiggy", r.payee)
        assertEquals("432112345678", r.reference)
        assertEquals("SBI", r.bankName)
    }

    @Test
    fun hdfcSentMultiline() {
        val r = parse(
            "VK-HDFCBK-S",
            "Sent Rs.250.00\nFrom HDFC Bank A/C *1234\nTo ZOMATO LIMITED\nOn 13/11/26\nRef 432112345679\n" +
                "Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808"
        )
        assertNotNull(r); r!!
        assertEquals(250.0, r.amount, 0.001)
        assertEquals("Zomato Limited", r.payee)
        assertEquals("432112345679", r.reference)
        assertEquals("1234", r.accountTail)
    }

    @Test
    fun iciciDebitedCredited() {
        val r = parse(
            "JM-ICICIT-S",
            "ICICI Bank Acct XX123 debited for Rs 99.00 on 13-Nov-26; BLINKIT credited. UPI:432112345680. " +
                "Call 18002662 for dispute. SMS BLOCK 123 to 9215676766."
        )
        assertNotNull(r); r!!
        assertEquals(99.0, r.amount, 0.001)
        assertEquals("Blinkit", r.payee)
        assertEquals("432112345680", r.reference)
    }

    @Test
    fun kotakSentToVpa() {
        val r = parse(
            "AX-KOTAKB-S",
            "Sent Rs.1,250.50 from Kotak Bank AC X1234 to swiggy.instamart@icici on 13-11-26.UPI Ref 432112345681. " +
                "Not you, https://kotak.com/KBANKT/Fraud"
        )
        assertNotNull(r); r!!
        assertEquals(1250.50, r.amount, 0.001)
        assertEquals("Swiggy Instamart", r.payee)
        assertEquals("swiggy.instamart@icici", r.vpa)
        assertEquals("432112345681", r.reference)
    }

    @Test
    fun iciciCardSpend() {
        val r = parse(
            "VM-ICICIT-S",
            "INR 500.00 spent on ICICI Bank Card XX9876 on 13-Nov-26 at AMAZON PAY INDIA. " +
                "Avl Lmt: INR 1,00,000.00. To dispute, call 18002662."
        )
        assertNotNull(r); r!!
        assertEquals(500.0, r.amount, 0.001)
        assertEquals("Amazon Pay India", r.payee)
        assertEquals("Card", r.channel)
        assertEquals("9876", r.accountTail)
    }

    @Test
    fun atmWithdrawal() {
        val r = parse(
            "BP-CANBNK-S",
            "Rs.2000.00 withdrawn from your A/c XX797 at ATM on 13-11-26. Avl Bal Rs.5000.00 -Canara Bank"
        )
        assertNotNull(r); r!!
        assertEquals(2000.0, r.amount, 0.001)
        assertEquals("ATM Withdrawal", r.payee)
        assertEquals("ATM", r.channel)
    }

    @Test
    fun unknownBankHeaderStillParsed() {
        val r = parse(
            "VM-XYZBNK-S",
            "Your A/c XX5555 is debited with INR 75.00 towards UPI payment to TEA STALL. UPI Ref 432112345682"
        )
        assertNotNull(r); r!!
        assertEquals(75.0, r.amount, 0.001)
        assertEquals("Bank", r.bankName)
        assertEquals("432112345682", r.reference)
    }

    // ------------------------------------------------------------ must be ignored

    @Test
    fun creditIgnored() {
        assertNull(
            parse("AX-AXISBK-S", "INR 500.00 credited to A/c no. XX0217 on 13-11-26 by UPI/P2A/123456789012/RAHUL. Axis Bank")
        )
    }

    @Test
    fun otpIgnored() {
        assertNull(parse("VM-HDFCBK-S", "OTP for txn of Rs 500.00 on HDFC Bank Card x1234 is 123456. Do not share."))
    }

    @Test
    fun collectRequestIgnored() {
        assertNull(parse("JD-BOBTXN-S", "RAHUL has requested money of Rs.200.00 from your A/c via UPI. Pay or decline in app."))
    }

    @Test
    fun upcomingDebitIgnored() {
        assertNull(parse("AD-SBIUPI-S", "Rs 499.00 will be debited from your A/c X1234 on 15-11-26 towards NETFLIX mandate."))
    }

    @Test
    fun failedIgnored() {
        assertNull(parse("VK-HDFCBK-S", "UPI txn of Rs.100.00 from A/C *1234 to ZOMATO failed. Amount if debited will be reversed."))
    }

    @Test
    fun phoneNumberSenderIgnored() {
        assertNull(parse("+919876543210", "Rs.500.00 debited from A/c XX1234 to SCAMMER. Ref 432112345683"))
    }

    @Test
    fun promoIgnored() {
        assertNull(parse("VM-HDFCBK-P", "Get a pre-approved loan of Rs 5,00,000 on your account. Click here to apply."))
    }
}
