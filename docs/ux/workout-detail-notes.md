# Workout Detail Wireframe Notes

Canonical wireframe: [`workout-detail.puml`](workout-detail.puml)

## Purpose

The Workout Detail screen lets the user inspect a workout, adjust workout-level playback options, inspect steps, update an installed bucket workout when a newer version exists, and start the workout.

## Current structure

The screen is organized into four persistent layers:

1. App bar with the workout name and overflow actions.
2. Compact workout summary header.
3. `Overview` and `Steps` tabs.
4. A prominent Start Workout action at the bottom.

An update banner appears between the summary header and tabs when a newer bucket version is available.

## Overview tab

The wireframe represents the main information hierarchy rather than every implementation detail:

- workout source when available
- description
- tags
- workout-level options
- voice guidance configuration
- background music configuration

## Steps tab

The `Steps` tab is intentionally represented only as a tab entry in the first wireframe iteration. A dedicated step-list wireframe should be added separately because step cards contain their own demonstration-media and recording interactions.

## Design rule

The wireframe is the expected UX structure, not a pixel-perfect Flutter specification. If implementation and wireframe differ intentionally after UX review, update the wireframe so the accepted design remains documented.
