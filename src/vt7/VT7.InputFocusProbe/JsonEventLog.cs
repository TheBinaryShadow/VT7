using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace VT7.InputFocusProbe
{
    internal sealed class JsonEventLog : IDisposable
    {
        private readonly object _gate = new object();
        private readonly StreamWriter _writer;
        private long _sequence;

        internal JsonEventLog(string path)
        {
            _writer = new StreamWriter(path, false, new UTF8Encoding(false)) { AutoFlush = true };
        }

        internal long Count
        {
            get { lock (_gate) return _sequence; }
        }

        internal void Write(string source, string eventName, params KeyValuePair<string, object?>[] fields)
        {
            lock (_gate)
            {
                _sequence++;
                var json = new StringBuilder(256);
                json.Append('{');
                Property(json, "schema", "vt7-i01-event-v1", false);
                Property(json, "sequence", _sequence, true);
                Property(json, "utc", DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture), true);
                Property(json, "source", source, true);
                Property(json, "event", eventName, true);
                foreach (var field in fields) Property(json, field.Key, field.Value, true);
                json.Append('}');
                _writer.WriteLine(json.ToString());
            }
        }

        internal static void Property(StringBuilder json, string name, object? value, bool comma)
        {
            if (comma) json.Append(',');
            String(json, name);
            json.Append(':');
            Value(json, value);
        }

        internal static void Value(StringBuilder json, object? value)
        {
            switch (value)
            {
                case null:
                    json.Append("null");
                    break;
                case bool flag:
                    json.Append(flag ? "true" : "false");
                    break;
                case byte number:
                    json.Append(number.ToString(CultureInfo.InvariantCulture));
                    break;
                case short number:
                    json.Append(number.ToString(CultureInfo.InvariantCulture));
                    break;
                case int number:
                    json.Append(number.ToString(CultureInfo.InvariantCulture));
                    break;
                case long number:
                    json.Append(number.ToString(CultureInfo.InvariantCulture));
                    break;
                case uint number:
                    json.Append(number.ToString(CultureInfo.InvariantCulture));
                    break;
                default:
                    String(json, Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty);
                    break;
            }
        }

        internal static void String(StringBuilder json, string value)
        {
            json.Append('"');
            foreach (var character in value)
            {
                switch (character)
                {
                    case '"': json.Append("\\\""); break;
                    case '\\': json.Append("\\\\"); break;
                    case '\b': json.Append("\\b"); break;
                    case '\f': json.Append("\\f"); break;
                    case '\n': json.Append("\\n"); break;
                    case '\r': json.Append("\\r"); break;
                    case '\t': json.Append("\\t"); break;
                    default:
                        if (character < 0x20)
                            json.Append("\\u").Append(((int)character).ToString("x4", CultureInfo.InvariantCulture));
                        else
                            json.Append(character);
                        break;
                }
            }
            json.Append('"');
        }

        public void Dispose()
        {
            lock (_gate) _writer.Dispose();
        }
    }
}
