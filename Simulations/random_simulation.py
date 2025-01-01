import random
import numpy as np
from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple
import matplotlib.pyplot as plt
from concurrent.futures import ProcessPoolExecutor
import time
import json

@dataclass
class SimulationConfig:
    min_value: int = 1
    max_value: int = 100
    trials: int = 1000
    seed: Optional[int] = None
    parallel: bool = False
    num_processes: int = 4
    batch_size: Optional[int] = None

@dataclass
class SimulationResults:
    raw_data: List[int]
    statistics: Dict[str, float]
    runtime: float
    config: SimulationConfig

    def to_json(self) -> str:
        """Convert results to JSON format"""
        return json.dumps({
            'statistics': self.statistics,
            'runtime': self.runtime,
            'config': self.config.__dict__
        }, indent=2)

    def save_to_file(self, filename: str):
        """Save results to a file"""
        with open(filename, 'w') as f:
            json.dump({
                'statistics': self.statistics,
                'runtime': self.runtime,
                'config': self.config.__dict__
            }, f, indent=2)

class RandomSimulation:
    def __init__(self, config: SimulationConfig):
        self.config = config
        if config.seed is not None:
            random.seed(config.seed)
            np.random.seed(config.seed)

    def _generate_batch(self, size: int) -> List[int]:
        """Generate a batch of random numbers"""
        return [random.randint(self.config.min_value, self.config.max_value) 
                for _ in range(size)]

    def _parallel_simulation(self) -> List[int]:
        """Run simulation in parallel using multiple processes"""
        batch_size = self.config.batch_size or (self.config.trials // self.config.num_processes)
        batches = [(batch_size,) for _ in range(self.config.trials // batch_size)]
        
        with ProcessPoolExecutor(max_workers=self.config.num_processes) as executor:
            results = list(executor.map(self._generate_batch, [b[0] for b in batches]))
        
        return [num for batch in results for num in batch]

    def run(self) -> SimulationResults:
        """Run the simulation and return results"""
        start_time = time.time()
        
        if self.config.parallel and self.config.trials >= 10000:
            results = self._parallel_simulation()
        else:
            results = self._generate_batch(self.config.trials)

        # Calculate statistics
        np_results = np.array(results)
        statistics = {
            'mean': float(np.mean(np_results)),
            'median': float(np.median(np_results)),
            'std_dev': float(np.std(np_results)),
            'min': float(np.min(np_results)),
            'max': float(np.max(np_results)),
            'variance': float(np.var(np_results)),
            'skewness': float(self._calculate_skewness(np_results)),
            'kurtosis': float(self._calculate_kurtosis(np_results))
        }

        runtime = time.time() - start_time
        return SimulationResults(results, statistics, runtime, self.config)

    @staticmethod
    def _calculate_skewness(data: np.ndarray) -> float:
        """Calculate skewness of the data"""
        return float(np.mean(((data - np.mean(data)) / np.std(data)) ** 3))

    @staticmethod
    def _calculate_kurtosis(data: np.ndarray) -> float:
        """Calculate kurtosis of the data"""
        return float(np.mean(((data - np.mean(data)) / np.std(data)) ** 4) - 3)

    def visualize_results(self, results: SimulationResults, save_path: Optional[str] = None):
        """Create visualization of simulation results"""
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        
        # Histogram
        ax1.hist(results.raw_data, bins=30, edgecolor='black')
        ax1.set_title('Distribution of Results')
        ax1.set_xlabel('Value')
        ax1.set_ylabel('Frequency')
        
        # QQ Plot
        sorted_data = np.sort(results.raw_data)
        theoretical_quantiles = np.random.normal(
            np.mean(results.raw_data),
            np.std(results.raw_data),
            len(results.raw_data)
        )
        theoretical_quantiles.sort()
        
        ax2.scatter(theoretical_quantiles, sorted_data, alpha=0.5)
        ax2.plot([min(theoretical_quantiles), max(theoretical_quantiles)],
                [min(theoretical_quantiles), max(theoretical_quantiles)],
                'r--')
        ax2.set_title('Q-Q Plot')
        
        # Box Plot
        ax3.boxplot(results.raw_data)
        ax3.set_title('Box Plot')
        
        # Running Average
        running_mean = np.cumsum(results.raw_data) / np.arange(1, len(results.raw_data) + 1)
        ax4.plot(running_mean)
        ax4.set_title('Running Average')
        ax4.set_xlabel('Number of Trials')
        ax4.set_ylabel('Average Value')
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path)
            plt.close()
        else:
            plt.show()

def main():
    # Example usage with different configurations
    configs = [
        SimulationConfig(trials=1000, seed=42),
        SimulationConfig(trials=10000, parallel=True, num_processes=4),
        SimulationConfig(min_value=0, max_value=1000, trials=5000)
    ]

    for i, config in enumerate(configs):
        # Create and run simulation
        simulator = RandomSimulation(config)
        results = simulator.run()
        
        # Print results
        print(f"\nSimulation {i+1} Results:")
        print(f"Runtime: {results.runtime:.4f} seconds")
        print("\nStatistics:")
        for key, value in results.statistics.items():
            print(f"{key}: {value:.2f}")
        
        # Visualize results
        simulator.visualize_results(results, f"simulation_{i+1}_results.png")
        
        # Save results
        results.save_to_file(f"simulation_{i+1}_results.json")

if __name__ == "__main__":
    main()