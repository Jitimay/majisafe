import { useQuery } from '@tanstack/react-query';
import * as analyticsApi from '../api/analytics.js';

export function useRecommendation(stationId) {
  return useQuery({
    queryKey: ['recommendation', stationId],
    queryFn: () => analyticsApi.getRecommendation(stationId),
    refetchInterval: 30_000,
    enabled: Boolean(stationId),
  });
}
