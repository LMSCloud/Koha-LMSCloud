[% PROCESS 'accounts.inc' %]
<form method="post" action="opac-account-pay.pl" class="form-horizontal">
    [% IF ( ACCOUNT_LINES ) %]

        [% IF ENABLE_OPAC_PAYMENTS %]
            <p>Select any or all open fees for online payment. <a href="#" id="CheckOpenFees"> Select all</a> | <a href="#" id="UncheckOpenFees">Clear all</a></p>
        [% END %]

        <table class="table table-bordered table-striped" id="finestable">
            <caption class="sr-only">Your charges</caption>
            <thead>
                <tr>
                    [% IF ENABLE_OPAC_PAYMENTS %]<th>&nbsp;</th>[% END %]
                    <th>Created</th>
                    <th>Updated</th>
                    <th>Type</th>
                    <th>Description</th>
                    <th>Amount</th>
                    <th>Amount outstanding</th>
                </tr>
            </thead>

            <tbody>
                [% FOREACH ACCOUNT_LINE IN ACCOUNT_LINES %]
                    [% IF ACCOUNT_LINE.amountoutstanding > 0 || ACCOUNT_LINE.amountoutstanding < 0 %]<tr class="outstanding">[% ELSE %]<tr>[% END%]
                        [% IF ENABLE_OPAC_PAYMENTS %]
                            <td>
                                [% IF ACCOUNT_LINE.amountoutstanding > 0 && paymentsMinimumPatronAgeReached %]
                                    [% SET DISPLAY_PAYMENT_BLOCK = 1 %]
                                    <input class="checkbox-pay pay-online hidden" name="accountline" type="checkbox" id="checkbox-pay-[% ACCOUNT_LINE.accountlines_id | html %]" value="[% ACCOUNT_LINE.accountlines_id | html %]">
                                    <input type="hidden" id="amount-[% ACCOUNT_LINE.accountlines_id | html %]" value="[% ACCOUNT_LINE.amountoutstanding | html %]" />
                                [% END %]
                            </td>
                        [% END %]
                        <td data-order="[% ACCOUNT_LINE.date | html %]">[% ACCOUNT_LINE.date | $KohaDates %]</td>
                        <td data-order="[% ACCOUNT_LINE.timestamp | html %]">[% ACCOUNT_LINE.timestamp | $KohaDates with_hours = 1 %]</td>
                        <td>
                            [% PROCESS account_type_description account=ACCOUNT_LINE %]
                        </td>
                        <td>
                            [%- IF ACCOUNT_LINE.payment_type %][% AuthorisedValues.GetByCode('PAYMENT_TYPE', ACCOUNT_LINE.payment_type, 1) | html %][% END %]
                            [%- IF ACCOUNT_LINE.description %][% ACCOUNT_LINE.description | html %][% END %]
                            [% IF ACCOUNT_LINE.itemnumber %]([% ACCOUNT_LINE.item.biblio.title | html %])[% END %]
                        </td>
                        [% IF ( ACCOUNT_LINE.is_credit ) %]<td class="credit">[% ACCOUNT_LINE.amount * -1 | $Price %][% ELSE %]<td class="debit">[% ACCOUNT_LINE.amount | $Price %][% END %]</td>
                        [% IF ( ACCOUNT_LINE.is_credit ) %]<td class="credit">[% ACCOUNT_LINE.amountoutstanding * -1 | $Price %][% ELSE %]<td class="debit">[% ACCOUNT_LINE.amountoutstanding | $Price %][% END %]</td>
                    </tr>
                [% END %]
            </tbody>

            <tfoot>
                <tr>
                    [%- IF ENABLE_OPAC_PAYMENTS -%]
                        [%- SET COLSPAN = 6 -%]
                    [%- ELSE -%]
                        [%- SET COLSPAN = 5 -%]
                    [%- END -%]
                    <th class="sum" colspan="[% COLSPAN | html %]">Total due</th>
                    <td class="sum">[% total | $Price %]</td>
                </tr>
                [% IF outstanding_credits.total_outstanding < 0 %]
                [% FOREACH outstanding_credit IN outstanding_credits %]
                    [% IF outstanding_credit.amountoutstanding < 0 %]<tr class="outstanding">[% ELSE %]<tr>[% END%]
                        [% IF ENABLE_OPAC_PAYMENTS %]<td></td>[% END %]
                        <td><span title="[% outstanding_credit.date | html %]">[% outstanding_credit.date | $KohaDates %]</span></td>
                        <td><span title="[% outstanding_credit.timestamp | html %]">[% outstanding_credit.date | $KohaDates with_hours = 1 %]</span></td>
                        <td>
                            [% PROCESS account_type_description account=outstanding_credit %]
                        </td>
                        <td>
                            [%- IF outstanding_credit.payment_type %][% AuthorisedValues.GetByCode('PAYMENT_TYPE', outstanding_credit.payment_type, 1) | html %][% END %]
                            [%- IF outstanding_credit.description %][% outstanding_credit.description | html %][% END %]
                            [% IF outstanding_credit.itemnumber %]([% outstanding_credit.item.biblio.title | html %])[% END %]
                        </td>
                        <td class="credit">[% outstanding_credit.amount * -1 | $Price %]</td>
                        <td class="credit">[% outstanding_credit.amountoutstanding * -1 | $Price %]</td>
                    </tr>
                [% END %]
                <tr>
                    <th class="sum" colspan="[% COLSPAN | html %]">Total due if credit(s) applied:</th>
                    <td class="sum">[% total + outstanding_credits.total_outstanding | $Price %]</td>
                </tr>
                [% END %]
            </tfoot>

        </table>


    [% ELSE %]
        <h3>You have no fines or charges</h3>
    [% END # /IF ( ACCOUNT_LINES )  %]

    [% FOREACH r IN relatives %]
        <h3 id="g[% r.patron.id | html %]">[% r.patron.firstname | html %] [% r.patron.surname | html %]'s fines and charges</h3>

        <table class="table table-bordered table-striped" id="finestable-[% r.id | html %]">
            <thead>
                <tr>
                    [% IF ENABLE_OPAC_PAYMENTS %]<th>&nbsp;</th>[% END %]
                    <th>Created</th>
                    <th>Updated</th>
                    <th>Type</th>
                    <th>Description</th>
                    <th>Amount</th>
                    <th>Amount outstanding</th>
                </tr>
            </thead>

            <tbody>
                [% SET account_sum = 0 %]
                [% FOREACH a IN r.accountlines %]
                    [% SET account_sum = account_sum + a.amountoutstanding %]
                    <tr>
                        [% IF ENABLE_OPAC_PAYMENTS %]
                            <td>
                                [% IF a.amountoutstanding > 0 %]
                                    [% SET DISPLAY_PAYMENT_BLOCK = 1 %]
                                    <input class="checkbox-pay pay-online hidden" name="accountline" type="checkbox" id="checkbox-pay-[% a.accountlines_id | html %]" value="[% a.accountlines_id | html %]">
                                    <input type="hidden" id="amount-[% a.accountlines_id | html %]" value="[% a.amountoutstanding | html %]" />
                                [% END %]
                            </td>
                        [% END %]
                        <td data-order="[% a.date | html %]">[% a.date | $KohaDates %]</td>
                        <td data-order="[% a.timestamp | html %]">[% a.timestamp | $KohaDates with_hours = 1 %]</td>
                        <td>
                            [% PROCESS account_type_description account=a %]
                        </td>
                        <td>
                            [%- IF a.payment_type %][% AuthorisedValues.GetByCode('PAYMENT_TYPE', a.payment_type, 1) | html %][% END %]
                            [%- IF a.description %][% a.description | html %][% END %]
                            [% IF a.itemnumber %]([% a.item.biblio.title | html %])[% END %]
                        </td>
                        [% IF ( a.amount < 0 ) %]<td class="credit">[% ELSE %]<td class="debit">[% END %][% a.amount | $Price %]</td>
                        [% IF ( a.amountoutstanding < 0 ) %]<td class="credit">[% ELSE %]<td class="debit">[% END %][% a.amountoutstanding | $Price %]</td>
                    </tr>
                [% END %]
            </tbody>

            <tfoot>
                <tr>
                    [%- IF ENABLE_OPAC_PAYMENTS -%]
                        [%- SET COLSPAN = 6 -%]
                    [%- ELSE -%]
                        [%- SET COLSPAN = 5 -%]
                    [%- END -%]
                    <th class="sum" colspan="[% COLSPAN | html %]">Total due</th>
                    <td class="sum">[% account_sum | $Price %]</td>
                </tr>
            </tfoot>
        </table>
    [% END # /FOREACH r %]

    [% IF ENABLE_OPAC_PAYMENTS && DISPLAY_PAYMENT_BLOCK %]
        <fieldset class="pay-online hidden">
            <legend>Pay selected fines and charges</legend>
            <span class="help-block"><h2>Payment method</h2></span>
            <input type="hidden" id="paymentTypeVariantKoha" name="paymentTypeVariantKoha" value="not_set" />

            [% FOREACH p IN plugins %]

                [% IF p.get_metadata.paymentTypeVariants %]    <!-- addition by LMSCloud -->

                    [% FOREACH ptVariant IN p.opac_payment_variants_per_type(logged_in_user.branchcode, p.get_metadata.paymentTypes, p.get_metadata.paymentTypeVariants) %]

                        [% IF ptVariant == 'GiroSolutionCreditcard' %]
                            <div class="control-group">
                                <label class="radio">
                                    <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" onclick="paymentTypeVariantKoha.value = '[% ptVariant %]';" />
                                    <div style="display: inline-block;">
                                        <strong style="margin:5px;" > credit card payment via S-Public Services </strong><br>
                                        [% FOREACH ptVariantIcon IN p.opac_online_payment_get_icons(logged_in_user.branchcode, ptVariant) %]
                                            <img style="max-width:64px; width:auto; max-height:26px; height:auto; margin:5px;" src="https://static.lmscloud.net/images/epayment/[% ptVariantIcon %]">
                                        [% END %]
                                    </div>
                                    <br><a title="S-Public Services - digital payment and administration solutions" target="_blank" href="https://s-publicservices.de/">More information about S-Public Services</a>
                                </label>
                            </div>
                        [% END %]

                        [% IF ptVariant == 'GiroSolutionGiropay' %]
                            <div class="control-group">
                                <label class="radio">
                                    <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" onclick="paymentTypeVariantKoha.value = '[% ptVariant %]';" />
                                    <div style="display: inline-block;">
                                    [% FOREACH ptVariantIcon IN p.opac_online_payment_get_icons(logged_in_user.branchcode, ptVariant) %]
                                        <img style="margin:5px;" src="https://static.lmscloud.net/images/epayment/[% ptVariantIcon %]">
                                    [% END %]
                                    </div>
                                    <br><a href="https://www.giropay.de" target="_blank" title="GIROPAY – SECURE ONLINE PAYMENT">More information about Giropay</a>
                                </label>
                            </div>
                        [% END %]

                        [% IF ptVariant == 'GiroSolutionPaypage' %]
                            <div class="control-group">
                                <label class="radio">
                                    <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" onclick="paymentTypeVariantKoha.value = '[% ptVariant %]';" />
                                    <div style="display: inline-block;">
                                        <strong style="margin:5px;" > online payment via S-Public Services </strong><br>
                                        [% FOREACH ptVariantIcon IN p.opac_online_payment_get_icons(logged_in_user.branchcode, ptVariant) %]
                                            <img style="max-width:64px; width:auto; max-height:26px; height:auto; margin:5px;" src="https://static.lmscloud.net/images/epayment/[% ptVariantIcon %]">
                                        [% END %]
                                    </div>
                                    <br><a title="S-Public Services - digital payment and administration solutions" target="_blank" href="https://s-publicservices.de/">More information about S-Public Services</a>
                                </label>
                            </div>
                        [% END %]

                        [% IF ptVariant == 'Epay21Paypage' %]
                            <div class="control-group">
                                <label class="radio">
                                    <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" onclick="paymentTypeVariantKoha.value = '[% ptVariant %]';" />
                                    <div style="display: inline-block;">
                                        <strong style="margin:5px;" > online payment via ekom21/epay21 </strong><br>
                                        [% FOREACH ptVariantIcon IN p.opac_online_payment_get_icons(logged_in_user.branchcode, ptVariant) %]
                                            <img style="max-width:64px; width:auto; max-height:26px; height:auto; margin:5px;" src="https://static.lmscloud.net/images/epayment/[% ptVariantIcon %]">
                                        [% END %]
                                    </div>
                                    <br><a href="https://www.ekom21.de/loesungen/epay21/" target="_blank" title="epay21 – payment in any situation">More information about Epay21</a>
                                </label>
                            </div>
                        [% END %]

                        [% IF ptVariant == 'PmPaymentPaypage' %]
                            <div class="control-group">
                                <label class="radio">
                                    <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" onclick="paymentTypeVariantKoha.value = '[% ptVariant %]';" />
                                    <div style="display: inline-block;">
                                        <strong style="margin:5px;" > online payment via pmPayment </strong><br>
                                        [% FOREACH ptVariantIcon IN p.opac_online_payment_get_icons(logged_in_user.branchcode, ptVariant) %]
                                            <img style="max-width:64px; width:auto; max-height:26px; height:auto; margin:5px;" src="https://static.lmscloud.net/images/epayment/[% ptVariantIcon %]">
                                        [% END %]
                                    </div>
                                    <br><a href="https://www.govconnect.de/Produkte/E-Government/pmPayment/" target="_blank" title="Online Payment with pmPayment">More information about pmPayment</a>
                                </label>
                            </div>
                        [% END %]

                        [% IF ptVariant == 'EPayBLPaypage' %]
                            <div class="control-group">
                                <label class="radio">
                                    <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" onclick="paymentTypeVariantKoha.value = '[% ptVariant %]';" />
                                    <div style="display: inline-block;">
                                        <strong style="margin:5px;" > online payment via ePayBL </strong><br>
                                        [% FOREACH ptVariantIcon IN p.opac_online_payment_get_icons(logged_in_user.branchcode, ptVariant) %]
                                            <img style="max-width:64px; width:auto; max-height:26px; height:auto; margin:5px;" src="https://static.lmscloud.net/images/epayment/[% ptVariantIcon %]">
                                        [% END %]
                                    </div>
                                    <br><a href="https://www.epaybl.de/" target="_blank" title="E-Payment Bund-Länder">More information about ePayBL</a>
                                </label>
                            </div>
                        [% END %]

                        [% IF ptVariant == 'SaferpayPaypage' %]
                            <div class="control-group">
                                <label class="radio">
                                    <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" onclick="paymentTypeVariantKoha.value = '[% ptVariant %]';" />
                                    <div style="display: inline-block;">
                                        <strong style="margin:5px;" > online payment via Saferpay </strong><br>
                                        [% FOREACH ptVariantIcon IN p.opac_online_payment_get_icons(logged_in_user.branchcode, ptVariant) %]
                                            <img style="max-width:64px; width:auto; max-height:26px; height:auto; margin:5px;" src="https://static.lmscloud.net/images/epayment/[% ptVariantIcon %]">
                                        [% END %]
                                    </div>
                                    <br><a href="https://www.payone.com/AT-de" target="_blank" title="Online Payment with Saferpay by payone">More information about Saferpay by payone</a>
                                </label>
                            </div>
                        [% END %]

                        <script type= "text/javascript">
                        paymentTypeVariantKoha.value = '[% ptVariant %]';
                        </script>

                    [% END %]
                    <br/>

                [% ELSE %]    <!-- standard Koha -->
                    <div class="control-group">
                        <label class="radio">
                            <input type="radio" name="payment_method" id="payment_method-[% p.class | html %]" value="[% p.class | html %]" checked="checked" />
                            [% p.get_metadata.name | html %]
                        </label>
                        <small class="help-block text-muted"></small>
                    </div>

                    <script type= "text/javascript">
                    paymentTypeVariantKoha.value = 'deleted';
                    </script>

                [% END %]

            [% END %]

            <div class="control-group">
                <input type="hidden" id="payment-amount" name="payment_amount" value="0" />
                <button id="submit-pay" type="submit" class="btn btn-primary" disabled="disabled">Make payment</button>
                <span id="amount-to-pay-label">
                    Amount to pay: <span id="amount-to-pay">0.00</span>
                </span>
            </div>
        </fieldset>
    [% END # /IF ENABLE_OPAC_PAYMENTS && DISPLAY_PAYMENT_BLOCK %]
</form>
