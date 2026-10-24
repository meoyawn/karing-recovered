import 'singbox_json.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:karing/screens/group_item_creator.dart';
import 'package:karing/screens/group_item_options.dart';
export 'singbox_json.dart' show SingboxOutboundType;

typedef SingboxOutboundOptions = SingboxJsonOptions;
typedef SingboxOutboundMultiplexOptions = SingboxJsonMultiplexOptions;
typedef SingboxOutboundSocksOptions = SingboxJsonOutboundSocksOptions;
typedef SingboxOutboundHTTPOptions = SingboxJsonOutboundHTTPOptions;
typedef SingboxOutboundShadowsocksOptions =
    SingboxJsonOutboundShadowsocksOptions;
typedef SingboxOutboundShadowsocksROptions =
    SingboxJsonOutboundShadowsocksROptions;
typedef SingboxOutboundShadowTLSOptions = SingboxJsonOutboundShadowTLSOptions;
typedef SingboxOutboundHysteriaOptions = SingboxJsonOutboundHysteriaOptions;
typedef SingboxOutboundHysteria2Options = SingboxJsonOutboundHysteria2Options;
typedef SingboxOutboundTrojanOptions = SingboxJsonOutboundTrojanOptions;
typedef SingboxOutboundVLESSOptions = SingboxJsonOutboundVLESSOptions;
typedef SingboxOutboundVMessOptions = SingboxJsonOutboundVMessOptions;
typedef SingboxOutboundWireguardPeerOptions =
    SingboxJsonOutboundWireguardPeerOptions;
typedef SingboxOutboundWireGuardOptions = SingboxJsonOutboundWireGuardOptions;
typedef SingboxOutboundTUICOptions = SingboxJsonOutboundTUICOptions;
typedef SingboxOutboundTorOptions = SingboxJsonOutboundTorOptions;
typedef SingboxOutboundSSHOptions = SingboxJsonOutboundSSHOptions;
typedef SingboxOutboundAnyTlsOptions = SingboxJsonGenericOutboundOptions;
typedef SingboxOutboundMieruOptions = SingboxJsonGenericOutboundOptions;
typedef SingboxOutboundNaiveOptions = SingboxJsonGenericOutboundOptions;

class SingboxOutboundMultiplexBrutalOptions {
  bool enabled;
  int? up_mbps;
  int? down_mbps;
  SingboxOutboundMultiplexBrutalOptions({
    this.enabled = false,
    this.up_mbps,
    this.down_mbps,
  });
  Future<List<GroupItem>> getWidgetOptions(
    BuildContext context,
    SetStateCallback? setstate,
  ) async => [
    GroupItem(
      options: [
        GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
            name: 'enabled',
            switchValue: enabled,
            onSwitch: (value) async {
              enabled = value;
              setstate?.call();
            },
          ),
        ),
        GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
            name: 'up_mbps',
            text: up_mbps?.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              up_mbps = int.tryParse(value);
            },
          ),
        ),
        GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
            name: 'down_mbps',
            text: down_mbps?.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              down_mbps = int.tryParse(value);
            },
          ),
        ),
      ],
    ),
  ];
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (up_mbps != null) 'up_mbps': up_mbps,
    if (down_mbps != null) 'down_mbps': down_mbps,
  };
  static SingboxOutboundMultiplexBrutalOptions? fromJsonStatic(
    Map<String, dynamic>? map,
  ) => map == null
      ? null
      : SingboxOutboundMultiplexBrutalOptions(
          enabled: map['enabled'] ?? false,
          up_mbps: map['up_mbps'],
          down_mbps: map['down_mbps'],
        );
}
