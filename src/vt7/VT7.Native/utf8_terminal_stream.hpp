// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once

#include <til/u8u16convert.h>

namespace VT7
{
    struct Utf8TerminalStreamSnapshot
    {
        uint64_t bytes{};
        uint64_t utf16Units{};
        uint32_t writes{};
        uint32_t generation{};
        uint32_t pendingBytes{};
        bool ended{ true };
        HRESULT lastError{ S_OK };
    };

    // Own one decoder per terminal session. A candidate state gives each write
    // strong decoder-state semantics if conversion or TerminalCore fails.
    class Utf8TerminalStream final
    {
    public:
        void Begin() noexcept
        {
            _state.reset();
            _snapshot = {};
            _snapshot.generation = ++_generation;
            _snapshot.ended = false;
        }

        void Abandon() noexcept
        {
            _state.reset();
            _snapshot.pendingBytes = 0;
            _snapshot.ended = true;
        }

        template<typename Writer>
        HRESULT Write(const std::string_view bytes, Writer&& writer) noexcept
        {
            if (_snapshot.ended)
            {
                _snapshot.lastError = HRESULT_FROM_WIN32(ERROR_INVALID_STATE);
                return _snapshot.lastError;
            }
            if (bytes.empty())
            {
                return S_OK;
            }

            auto candidate = _state;
            std::wstring decoded;
            const auto conversion = til::u8u16(bytes, decoded, candidate);
            if (FAILED(conversion))
            {
                _snapshot.lastError = conversion;
                return conversion;
            }

            try
            {
                if (!decoded.empty())
                {
                    writer(std::wstring_view{ decoded });
                }
            }
            catch (...)
            {
                _snapshot.lastError = wil::ResultFromCaughtException();
                return _snapshot.lastError;
            }

            _state = candidate;
            _snapshot.bytes += bytes.size();
            _snapshot.utf16Units += decoded.size();
            ++_snapshot.writes;
            _snapshot.pendingBytes = _state.have;
            _snapshot.lastError = S_OK;
            return S_OK;
        }

        HRESULT End() noexcept
        {
            if (_snapshot.ended)
            {
                return _snapshot.lastError;
            }

            _snapshot.ended = true;
            if (_state.have != 0)
            {
                _state.reset();
                _snapshot.pendingBytes = 0;
                _snapshot.lastError = HRESULT_FROM_WIN32(ERROR_NO_UNICODE_TRANSLATION);
                return _snapshot.lastError;
            }

            _snapshot.lastError = S_OK;
            return S_OK;
        }

        const Utf8TerminalStreamSnapshot& Snapshot() const noexcept
        {
            return _snapshot;
        }

    private:
        til::u8state _state{};
        Utf8TerminalStreamSnapshot _snapshot{};
        uint32_t _generation{};
    };
}
