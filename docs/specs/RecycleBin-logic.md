# Recycle Bin Logic

> Status: retired by the 2026-06-14 product-owner decision. This file remains only so historical links resolve; it is not an active product contract.

## Current Contract

Ohana no longer ships a user-visible recoverable deletion model. Member and archive deletion is:

- explicit irreversible confirmation;
- CloudSync deletion tombstone metadata written when the entity participates in sync;
- immediate local physical deletion through the owning command/service boundary;
- no recovery UI, restore command, retention window, or user-visible deleted state.

The active source of truth is:

- `docs/specs/product-foundation.md` D8, D16, G5, and G6;
- `Ohana/Domain/Services/PhysicalDeletionService.swift`;
- module rules that delegate irreversible deletion to that service.

## Legacy Compatibility

Stores that already migrated through the cancelled GAP-2 schema may still contain legacy storage columns or the `RecycleBinBatch` model row. Those artifacts are retained only to keep existing stores open and to support future migration cleanup. No active UI, backup, command, route, audit, or restore flow may treat them as a product feature.
