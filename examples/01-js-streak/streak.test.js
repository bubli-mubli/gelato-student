import { test } from 'node:test';
import assert from 'node:assert/strict';
import { longestStreak } from './streak.js';

test('пустой список', () => assert.equal(longestStreak([]), 0));
test('ни одного дня', () => assert.equal(longestStreak([false, false]), 0));
test('серия в конце', () => assert.equal(longestStreak([true, true, false, true, true, true]), 3));
test('серия в начале', () => assert.equal(longestStreak([true, true, true, false, true]), 3));
test('все дни', () => assert.equal(longestStreak([true, true, true, true]), 4));
