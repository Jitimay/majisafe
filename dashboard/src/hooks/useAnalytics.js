import { useQuery } from '@tanstack/react-query';
import * as analyticsApi from '../api/analytics.js';

export function useDailyUsage(stationId, days = 7) {
  return useQuery({
    queryKey: ['dailyUsage', stationId, days],
    queryFn: () => analyticsApi.getDailyUsage(stationId, days),
    refetchInterval: 30_000,
    enabled: Boolean(stationId),
  });
}

export function useHourlyHeatmap(stationId) {
  return useQuery({
    queryKey: ['hourlyHeatmap', stationId],
    queryFn: () => analyticsApi.getHourlyHeatmap(stationId),
    refetchInterval: 30_000,
    enabled: Boolean(stationId),
  });
}

export function useDepletionRate(stationId) {
  return useQuery({
    queryKey: ['depletionRate', stationId],
    queryFn: () => analyticsApi.getDepletionRate(stationId),
    refetchInterval: 30_000,
    enabled: Boolean(stationId),
  });
}

export function useTimeToEmpty(stationId) {
  return useQuery({
    queryKey: ['timeToEmpty', stationId],
    queryFn: () => analyticsApi.getTimeToEmpty(stationId),
    refetchInterval: 30_000,
    enabled: Boolean(stationId),
  });
}
