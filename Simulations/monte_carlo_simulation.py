import numpy as np
import matplotlib.pyplot as plt
from dataclasses import dataclass
from typing import List, Dict, Tuple, Optional, Callable
import time
from concurrent.futures import ProcessPoolExecutor
import json
from abc import ABC, abstractmethod

@dataclass
class MonteCarloConfig:
    num_samples: int = 10000
    num_processes: int = 4
    seed: Optional[int] = None
    batch_size: Optional[int] = None
    use_numpy: bool = True
    store_points: bool = False
    convergence_threshold: float = 1e-6
    max_iterations: int = 100

class MonteCarloSimulation(ABC):
    @abstractmethod
    def run_trial(self) -> Tuple[float, Optional[Dict]]:
        pass

    @abstractmethod
    def get_exact_value(self) -> float:
        pass

class PiEstimation(MonteCarloSimulation):
    def __init__(self, config: MonteCarloConfig):
        self.config = config
        if config.seed is not None:
            np.random.seed(config.seed)
            random.seed(config.seed)
        self.points: List[Tuple[float, float, bool]] = []

    def run_trial(self) -> Tuple[float, Optional[Dict]]:
        if self.config.use_numpy:
            return self._run_numpy_trial()
        return self._run_python_trial()

    def _run_numpy_trial(self) -> Tuple[float, Optional[Dict]]:
        x = np.random.uniform(-1, 1, self.config.num_samples)
        y = np.random.uniform(-1, 1, self.config.num_samples)
        distances = x**2 + y**2
        inside_circle = np.sum(distances <= 1)
        
        if self.config.store_points:
            self.points.extend([(x[i], y[i], distances[i] <= 1) 
                              for i in range(self.config.num_samples)])
        
        pi_estimate = (inside_circle / self.config.num_samples) * 4
        return pi_estimate, {"inside_circle": int(inside_circle)}

    def _run_python_trial(self) -> Tuple[float, Optional[Dict]]:
        inside_circle = 0
        for _ in range(self.config.num_samples):
            x = random.uniform(-1, 1)
            y = random.uniform(-1, 1)
            distance = x**2 + y**2
            is_inside = distance <= 1
            
            if self.config.store_points:
                self.points.append((x, y, is_inside))
            
            if is_inside:
                inside_circle += 1
        
        pi_estimate = (inside_circle / self.config.num_samples) * 4
        return pi_estimate, {"inside_circle": inside_circle}

    def get_exact_value(self) -> float:
        return np.pi

class MonteCarloAnalyzer:
    def __init__(self, simulation: MonteCarloSimulation, config: MonteCarloConfig):
        self.simulation = simulation
        self.config = config
        self.results: List[float] = []
        self.runtime: float = 0
        self.convergence_history: List[float] = []

    def run_parallel(self) -> Dict:
        start_time = time.time()
        batch_size = self.config.batch_size or (self.config.num_samples // self.config.num_processes)
        
        with ProcessPoolExecutor(max_workers=self.config.num_processes) as executor:
            futures = [executor.submit(self.simulation.run_trial) 
                      for _ in range(self.config.num_processes)]
            results = [future.result()[0] for future in futures]
        
        self.results = results
        self.runtime = time.time() - start_time
        return self._analyze_results()

    def run_sequential(self) -> Dict:
        start_time = time.time()
        estimate = 0
        prev_estimate = float('inf')
        
        for i in range(self.config.max_iterations):
            result, _ = self.simulation.run_trial()
            self.results.append(result)
            
            estimate = np.mean(self.results)
            self.convergence_history.append(estimate)
            
            if abs(estimate - prev_estimate) < self.config.convergence_threshold:
                break
            
            prev_estimate = estimate
        
        self.runtime = time.time() - start_time
        return self._analyze_results()

    def _analyze_results(self) -> Dict:
        exact_value = self.simulation.get_exact_value()
        final_estimate = np.mean(self.results)
        
        return {
            'estimate': final_estimate,
            'exact_value': exact_value,
            'absolute_error': abs(final_estimate - exact_value),
            'relative_error': abs((final_estimate - exact_value) / exact_value),
            'standard_deviation': np.std(self.results),
            'runtime': self.runtime,
            'num_iterations': len(self.results)
        }

    def visualize(self, save_path: Optional[str] = None):
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))

        # Distribution of estimates
        ax1.hist(self.results, bins=30, edgecolor='black')
        ax1.axvline(np.pi, color='r', linestyle='--', label='True π')
        ax1.set_title('Distribution of π Estimates')
        ax1.set_xlabel('Estimate')
        ax1.set_ylabel('Frequency')
        ax1.legend()

        # Convergence plot
        ax2.plot(self.convergence_history)
        ax2.axhline(np.pi, color='r', linestyle='--', label='True π')
        ax2.set_title('Convergence History')
        ax2.set_xlabel('Iteration')
        ax2.set_ylabel('Estimate')
        ax2.legend()

        # Points plot (if stored)
        if isinstance(self.simulation, PiEstimation) and self.simulation.points:
            points = np.array(self.simulation.points)
            inside = points[:, 2].astype(bool)
            ax3.scatter(points[inside, 0], points[inside, 1], 
                       c='blue', alpha=0.1, label='Inside')
            ax3.scatter(points[~inside, 0], points[~inside, 1], 
                       c='red', alpha=0.1, label='Outside')
            circle = plt.Circle((0, 0), 1, fill=False, color='black')
            ax3.add_artist(circle)
            ax3.set_aspect('equal')
            ax3.set_title('Monte Carlo Points')
            ax3.legend()

        # Error convergence
        if self.convergence_history:
            errors = [abs(x - np.pi) for x in self.convergence_history]
            ax4.plot(errors)
            ax4.set_yscale('log')
            ax4.set_title('Error Convergence')
            ax4.set_xlabel('Iteration')
            ax4.set_ylabel('Absolute Error')

        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path)
            plt.close()
        else:
            plt.show()

def main():
    # Example usage with different configurations
    configs = [
        MonteCarloConfig(num_samples=10000, seed=42),
        MonteCarloConfig(num_samples=100000, use_numpy=True, store_points=True),
        MonteCarloConfig(num_samples=1000000, num_processes=8)
    ]

    for i, config in enumerate(configs):
        print(f"\nRunning simulation with {config.num_samples} samples...")
        
        # Initialize simulation
        simulation = PiEstimation(config)
        analyzer = MonteCarloAnalyzer(simulation, config)
        
        # Run analysis
        if config.num_samples >= 100000:
            results = analyzer.run_parallel()
        else:
            results = analyzer.run_sequential()
        
        # Print results
        print("\nResults:")
        for key, value in results.items():
            if isinstance(value, float):
                print(f"{key}: {value:.6f}")
            else:
                print(f"{key}: {value}")
        
        # Visualize results
        analyzer.visualize(f"monte_carlo_results_{i+1}.png")
        
        # Save results
        with open(f"monte_carlo_results_{i+1}.json", 'w') as f:
            json.dump(results, f, indent=2)

if __name__ == "__main__":
    main()