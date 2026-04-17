import { useQuery } from '@tanstack/react-query';
import * as stationsApi from '../api/stations.js';

export function useStations() {
  return useQuery({
    queryKey: ['stations'],
    queryFn: () => stationsApi.list(),
    refetchInterval: 30_000,
    retry: Infinity,
    retryDelay: 30_000,
  });
}
