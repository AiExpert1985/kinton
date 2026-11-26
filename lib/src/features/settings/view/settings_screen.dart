import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablets/src/common/providers/page_title_provider.dart';
import 'package:tablets/src/routers/go_router_provider.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:tablets/generated/l10n.dart';
import 'package:tablets/src/common/classes/db_cache.dart';
import 'package:tablets/src/common/functions/debug_print.dart';
import 'package:tablets/src/common/functions/user_messages.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/values/constants.dart';
import 'package:tablets/src/common/values/gaps.dart';
import 'package:tablets/src/common/widgets/custom_icons.dart';
import 'package:tablets/src/common/widgets/main_frame.dart';
import 'package:tablets/src/features/counters/repository/counter_repository_provider.dart';
import 'package:tablets/src/features/customers/model/customer.dart';
import 'package:tablets/src/features/customers/repository/customer_db_cache_provider.dart';
import 'package:tablets/src/features/customers/repository/customer_repository_provider.dart';
import 'package:tablets/src/features/home/view/home_screen.dart';
import 'package:tablets/src/features/settings/controllers/settings_form_data_notifier.dart';
import 'package:tablets/src/features/settings/model/settings.dart';
import 'package:tablets/src/features/settings/repository/settings_db_cache_provider.dart';
import 'package:tablets/src/features/settings/repository/settings_repository_provider.dart';
import 'package:tablets/src/features/settings/view/settings_keys.dart';

final paymentValues = [PaymentType.credit.name, PaymentType.cash.name];
final currencyValues = [Currency.dinar.name, Currency.dollar.name];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(settingsFormDataProvider);
    final settingDataNotifier = ref.read(settingsFormDataProvider.notifier);
    if (settingDataNotifier.data.isEmpty) {
      return const HomeScreen();
    }
    return const AppScreenFrame(SettingsParameters());
  }
}

class SettingsParameters extends ConsumerWidget {
  const SettingsParameters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(settingsRepositoryProvider);
    final settingDataNotifier = ref.read(settingsFormDataProvider.notifier);
    final dbCache = ref.read(settingsDbCacheProvider.notifier);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 15),
        child: Column(
          children: [
            Container(
              height: 550,
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 50),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FirstColumn(),
                  VerticalDivider(),
                  SecondColumn(),
                  VerticalDivider(),
                  ThirdColumn(),
                ],
              ),
            ),
            const Spacer(),

            // button only saves changes to Db, in case user didn't save, then his changes
            // will be only available in the current settings
            Center(
              child: IconButton(
                onPressed: () async {
                  final settingsData = settingDataNotifier.data;
                  // dbCache still holds the last saved value (form data is a separate copy)
                  final oldDuration = dbCache.data.isNotEmpty
                      ? dbCache.data[0][settingsMaxDebtDurationKey]
                      : null;
                  final newDuration = settingsData[settingsMaxDebtDurationKey];
                  final durationChanged = oldDuration != newDuration;
                  final customers = ref.read(customerDbCacheProvider);
                  final customerRepo = ref.read(customerRepositoryProvider);

                  final success = await repository
                      .updateItem(Settings.fromMap(settingsData));
                  if (!context.mounted) return;
                  if (!success) {
                    failureUserMessage(context, 'فشل حفظ الاعدادات');
                    return;
                  }
                  // mirror the change in dbCache only after db write succeeded
                  dbCache.update(settingsData, DbCacheOperationTypes.edit);

                  // when debt duration changes, apply it to all customers
                  // (request of Jihan - Shamil)
                  if (durationChanged) {
                    infoUserMessage(
                        context, "الرجاء الانتظار عدة دقائق حتى اكتمال التحديث");
                    int failed = 0;
                    for (var customerMap in customers) {
                      customerMap['paymentDurationLimit'] = newDuration;
                      final ok = await customerRepo
                          .updateItem(Customer.fromMap(customerMap));
                      if (!ok) failed++;
                    }
                    if (!context.mounted) return;
                    if (failed > 0) {
                      failureUserMessage(
                          context, 'فشل تحديث مدة الدين لـ $failed زبون');
                      return;
                    }
                    successUserMessage(context, 'تم تحديث مدة الدين لجميع الزبائن');
                  }
                  successUserMessage(context, 'تم حفظ الاعدادات');
                  // exit settings screen to home (same as drawer home button)
                  ref.read(pageTitleProvider.notifier).state = '';
                  context.goNamed(AppRoute.home.name);
                },
                icon: const SaveIcon(),
              ),
            ),
            VerticalGap.xl,
            const Text('version 0.80', style: TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
  }
}

class FirstColumn extends ConsumerWidget {
  const FirstColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SwitchButton(
            S.of(context).hide_amount_as_text, hideTransactionAmountAsTextKey),
        VerticalGap.xl,
        SwitchButton(
            S.of(context).hide_totals_row, hideMainScreenColumnTotalsKey),
        VerticalGap.xl,
        SwitchButton(
            S.of(context).hide_product_buying_price, hideProductBuyingPriceKey),
        VerticalGap.xl,
        SwitchButton(S.of(context).hide_customer_profit, hideCustomerProfitKey),
        VerticalGap.xl,
        SwitchButton(S.of(context).hide_product_profit, hideProductProfitKey),
        VerticalGap.xl,
        SwitchButton(S.of(context).hide_salesman_profit, hideSalesmanProfitKey),
        VerticalGap.xl,
        SwitchButton(
            S.of(context).show_barcode_when_printing, hideCompanyUrlBarCodeKey),
      ],
    );
  }
}

class SecondColumn extends ConsumerWidget {
  const SecondColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        RadioButtons(S.of(context).transaction_payment_type,
            settingsPaymentTypeKey, paymentValues),
        VerticalGap.xl,
        RadioButtons(S.of(context).settings_currency, settingsCurrencyKey,
            currencyValues),
        VerticalGap.xl,
        SettingsInputField(S.of(context).max_debt_duration_allowed,
            settingsMaxDebtDurationKey, FieldDataType.num.name),
        // SliderButton(
        //     S.of(context).max_debt_duration_allowed, settingsMaxDebtDurationKey, 0, 60, 30),
        VerticalGap.xl,
        SliderButton(S.of(context).num_printed_invoices,
            printedCustomerInvoicesKey, 0, 10, 5),
        VerticalGap.xl,
        SliderButton(S.of(context).num_printed_receipts,
            printedCustomerReceiptsKey, 0, 10, 5),
        VerticalGap.xxl,
      ],
    );
  }
}

class ThirdColumn extends ConsumerWidget {
  const ThirdColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SettingsInputField(S.of(context).max_debt_amount_allowed,
            settingsMaxDebtAmountKey, FieldDataType.num.name),
        VerticalGap.xl,
        SettingsInputField(S.of(context).settings_company_url, companyUrlKey,
            FieldDataType.text.name),
        VerticalGap.xl,
        SettingsInputField(S.of(context).settings_main_page_greeting,
            mainPageGreetingTextKey, FieldDataType.text.name),
        VerticalGap.xl,
        const CustomerInvoiceCounterField(),
      ],
    );
  }
}

class SettingLabel extends ConsumerWidget {
  const SettingLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 160,
      child: Text(
        label,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

class SliderButton extends ConsumerWidget {
  const SliderButton(this.label, this.propertyName, this.minNumber,
      this.maxNumber, this.intervals,
      {super.key});

  final String label;
  final String propertyName;
  final double minNumber;
  final double maxNumber;
  final double intervals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsDataNotifier = ref.read(settingsFormDataProvider.notifier);
    final currentValue = settingsDataNotifier.getProperty(propertyName);
    ref.watch(settingsFormDataProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SettingLabel(label),
        HorizontalGap.l,
        SfSlider(
          min: minNumber,
          max: maxNumber,
          value: currentValue,
          interval: intervals,
          // showTicks: true,
          showLabels: true,
          enableTooltip: true,
          // minorTicksPerInterval: 1,
          onChanged: (dynamic value) {
            settingsDataNotifier
                .updateProperties({propertyName: value.round()});
          },
        ),
      ],
    );
  }
}

class RadioButtons extends ConsumerWidget {
  const RadioButtons(this.label, this.propertyName, this.values, {super.key});
  final List<String> values;
  final String label;
  final String propertyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsDataNotifier = ref.read(settingsFormDataProvider.notifier);
    final currentValue = settingsDataNotifier.getProperty(propertyName);
    ref.watch(settingsFormDataProvider);
    return RadioGroup<String>(
      groupValue: currentValue,
      onChanged: (String? value) {
        settingsDataNotifier.updateProperties({propertyName: value});
      },
      child: Row(
        children: [
          SettingLabel(label),
          ...values.map(
            (buttonValue) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(translateDbTextToScreenText(context, buttonValue)),
                    VerticalGap.s,
                    Radio<String>(
                      value: buttonValue,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SwitchButton extends ConsumerWidget {
  const SwitchButton(this.label, this.propertyName, {super.key});
  final String label;
  final String propertyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsDataNotifier = ref.read(settingsFormDataProvider.notifier);
    final currentValue = settingsDataNotifier.getProperty(propertyName);
    ref.watch(settingsFormDataProvider);
    return Row(
      children: [
        SettingLabel(label),
        HorizontalGap.xl,
        Switch(
          value: currentValue,
          onChanged: (value) {
            settingsDataNotifier.updateProperties({propertyName: value});
          },
        ),
      ],
    );
  }
}

class SettingsInputField extends ConsumerStatefulWidget {
  const SettingsInputField(this.label, this.propertyName, this.dataType,
      {super.key});

  final String label;
  final String propertyName;
  final String dataType;

  @override
  ConsumerState<SettingsInputField> createState() => _SettingsInputFieldState();
}

class _SettingsInputFieldState extends ConsumerState<SettingsInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final settingsDataNotifier = ref.read(settingsFormDataProvider.notifier);
    dynamic currentValue =
        settingsDataNotifier.getProperty(widget.propertyName);
    if (widget.dataType == FieldDataType.num.name) {
      // show whole numbers without ".0" (e.g. 51.0 -> 51)
      if (currentValue is num && currentValue == currentValue.roundToDouble()) {
        currentValue = currentValue.toInt();
      }
      currentValue = currentValue.toString();
    }
    _controller = TextEditingController(text: currentValue);
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsDataNotifier = ref.watch(settingsFormDataProvider.notifier);

    return Row(
      children: [
        SettingLabel(widget.label),
        HorizontalGap.xl,
        SizedBox(
          width: 200,
          child: FormBuilderTextField(
            name: widget.propertyName,
            textAlign: TextAlign.center,
            // debt duration is whole days only
            inputFormatters: widget.propertyName == settingsMaxDebtDurationKey
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            onChanged: (value) {
              // note: debt duration is applied to all customers by the save button
              if (value == null) return; // Check for null
              dynamic newValue;
              if (widget.dataType == FieldDataType.num.name) {
                try {
                  newValue = double.parse(value);
                } catch (e) {
                  errorPrint('value is not a number');
                  return; // Exit if parsing fails
                }
              } else {
                newValue = value;
              }
              // note: don't write back to _controller here, it re-triggers
              // onChanged (FormBuilder listens to the controller) and loops
              settingsDataNotifier
                  .updateProperties({widget.propertyName: newValue});
            },
            decoration: formFieldDecoration(),
            controller: _controller,
          ),
        )
      ],
    );
  }
}

class CustomerInvoiceCounterField extends ConsumerStatefulWidget {
  const CustomerInvoiceCounterField({super.key});

  @override
  ConsumerState<CustomerInvoiceCounterField> createState() =>
      _CustomerInvoiceCounterFieldState();
}

class _CustomerInvoiceCounterFieldState
    extends ConsumerState<CustomerInvoiceCounterField> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  Future<void> _loadCurrentValue() async {
    final counterRepo = ref.read(counterRepositoryProvider);
    final currentValue = await counterRepo.getCurrentNumber('customerInvoice');
    if (mounted) {
      _controller.text = currentValue.toString();
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SettingLabel('رقم القائمة القادمة'),
        HorizontalGap.xl,
        SizedBox(
          width: 200,
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : FormBuilderTextField(
                  name: 'customerInvoiceCounter',
                  textAlign: TextAlign.center,
                  controller: _controller,
                  decoration: formFieldDecoration(),
                  onSubmitted: (value) async {
                    if (value == null || value.isEmpty) return;
                    final number = int.tryParse(value);
                    if (number == null) {
                      failureUserMessage(context, 'الرجاء ادخال رقم صحيح');
                      return;
                    }
                    try {
                      final counterRepo = ref.read(counterRepositoryProvider);
                      await counterRepo.initializeCounter(
                          'customerInvoice', number);
                      if (context.mounted) {
                        successUserMessage(context,
                            'تم تحديث رقم القائمة القادمة الى $number');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        failureUserMessage(context, 'خطأ في تحديث الرقم: $e');
                      }
                    }
                  },
                ),
        ),
      ],
    );
  }
}
