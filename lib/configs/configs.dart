import '../src/rust/api/property.dart' as rustProperty;

abstract class Config<T> {
  T _value;

  Config._(this._value);

  String propertyName();

  T parse(String value);

  String serialize(T value);

  get value => _value;

  Future<void> setValue(T value) async {
    await rustProperty.setProperty(
      key: propertyName(),
      value: serialize(value),
    );
    _value = value;
  }

  _init() async {
    _value = parse(
      await rustProperty.getProperty(key: propertyName()),
    );
  }
}

class BoolConfig extends Config<bool> {
  final String _name;
  final bool _defaultValue;

  BoolConfig._(this._name, this._defaultValue) : super._(false);

  @override
  String propertyName() => _name;

  @override
  bool parse(String value) {
    if (value == '') {
      return _defaultValue;
    }
    return value == 'true';
  }

  @override
  String serialize(bool value) {
    return value.toString();
  }
}

final zipOnSend = BoolConfig._('zip_on_send', false);

initConfigs() async {
  await zipOnSend._init();
}
